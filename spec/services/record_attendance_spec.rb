require "rails_helper"

RSpec.describe RecordAttendance do
  let(:operator) { create(:user) }
  let(:event) { create(:event, :open, event_date: Date.new(2026, 6, 1)) }
  let(:attendee) { create(:attendee, birthdate: Date.new(1998, 1, 1), gender: "male") } # 28 on event date → YAN

  def scan(payload = attendee.qr_payload, ev: event, user: operator)
    described_class.call(event: ev, qr_payload: payload, operator: user)
  end

  it "records attendance for a valid scan" do
    result = nil
    expect { result = scan }.to change(Attendance, :count).by(1)
    expect(result).to be_recorded
    expect(result).to be_success
    expect(result.http_status).to eq(:created)
    expect(result.attendee).to eq(attendee)
    expect(result.attendance.event).to eq(event)
    expect(result.attendance.operator).to eq(operator)
    expect(result.attendance.scanned_at).to be_within(2.seconds).of(Time.current)
  end

  it "snapshots the ministry classification as of the event date, not today" do
    old_event = create(:event, :open, event_date: Date.new(2020, 6, 1)) # attendee was 22 → YAN
    expect(scan(ev: old_event).attendance.ministry_classification).to eq(Ministry::YAN)

    # Same attendee at a much later event: 40 → Men's.
    later = create(:event, :open, event_date: Date.new(2038, 6, 1))
    expect(scan(ev: later).attendance.ministry_classification).to eq(Ministry::MENS)
  end

  it "keeps the snapshot even after the attendee ages into another ministry" do
    attendance = scan.attendance
    attendee.update!(birthdate: Date.new(1980, 1, 1))
    expect(attendance.reload.ministry_classification).to eq(Ministry::YAN)
  end

  it "accepts a bare token as well as the prefixed payload" do
    expect(scan(attendee.qr_token)).to be_recorded
  end

  it "broadcasts a dashboard refresh after recording" do
    expect(Turbo::StreamsChannel).to receive(:broadcast_refresh_to).with(event)
    scan
  end

  it "returns duplicate for a second scan without creating a record or changing the timestamp" do
    first = scan
    original_time = first.attendance.scanned_at

    travel 5.minutes do
      result = nil
      expect { result = scan }.not_to change(Attendance, :count)
      expect(result).to be_duplicate
      expect(result).to be_success
      expect(result.http_status).to eq(:ok)
      expect(result.attendance).to eq(first.attendance)
      expect(result.attendance.scanned_at).to eq(original_time)
      expect(result.message).to include(attendee.full_name)
    end
  end

  it "rejects an unknown QR token" do
    result = scan("attendee:does-not-exist")
    expect(result.status).to eq(:attendee_not_found)
    expect(result).to be_error
    expect(result.http_status).to eq(:not_found)
    expect(Attendance.count).to eq(0)
  end

  it "rejects blank payloads" do
    expect(scan("").status).to eq(:attendee_not_found)
  end

  it "rejects an inactive attendee" do
    attendee.deactivate!
    result = scan
    expect(result.status).to eq(:attendee_inactive)
    expect(Attendance.count).to eq(0)
  end

  it "rejects a closed event" do
    closed = create(:event, :closed)
    result = scan(ev: closed)
    expect(result.status).to eq(:event_closed)
    expect(result.http_status).to eq(:unprocessable_content)
    expect(Attendance.count).to eq(0)
  end

  it "rejects a draft event" do
    result = scan(ev: create(:event))
    expect(result.status).to eq(:event_not_open)
    expect(Attendance.count).to eq(0)
  end

  it "rejects a missing operator" do
    expect(scan(user: nil).status).to eq(:unauthorized)
  end

  it "rejects an attendee who was under 13 on the event date" do
    young = create(:attendee, birthdate: Date.current.prev_year(13)) # exactly 13 today
    old_event = create(:event, :open, event_date: Date.current.prev_year(2))
    result = scan(young.qr_payload, ev: old_event)
    expect(result.status).to eq(:unsupported_age)
    expect(Attendance.count).to eq(0)
  end

  it "re-checks event status inside the transaction (stale in-memory event)" do
    stale = Event.find(event.id)
    CloseEvent.call(event: event, user: create(:admin))
    expect(scan(ev: stale).status).to eq(:event_closed)
  end

  it "resolves a RecordNotUnique race to a duplicate result" do
    scan # existing row
    # Simulate losing the race: the pre-check and model validation both miss the row,
    # so only the database unique index stops the insert.
    allow(Attendance).to receive(:find_by).and_call_original
    allow(Attendance).to receive(:find_by).with(event_id: event.id, attendee_id: attendee.id).and_return(nil)
    allow_any_instance_of(Attendance).to receive(:valid?).and_return(true)
    result = scan
    expect(result).to be_duplicate
    expect(Attendance.count).to eq(1)
  end

  describe "concurrent scans", :concurrency do
    # Real threads need real commits, so disable the transactional wrapper here.
    self.use_transactional_tests = false

    after do
      Attendance.delete_all
      Event.delete_all
      Attendee.delete_all
      User.delete_all
    end

    it "creates exactly one attendance when the same QR is scanned simultaneously" do
      ev = create(:event, :open)
      att = create(:attendee)
      op = create(:user)

      barrier = Queue.new
      results = Array.new(6)
      threads = 6.times.map do |i|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            barrier.pop
            results[i] = described_class.call(event: ev, qr_payload: att.qr_payload, operator: op)
          end
        end
      end
      6.times { barrier << true }
      threads.each(&:join)

      expect(Attendance.where(event: ev, attendee: att).count).to eq(1)
      expect(results.count(&:recorded?)).to eq(1)
      expect(results.count(&:duplicate?)).to eq(5)
    end
  end
end

RSpec.describe RecordAttendance, "racing with event closure" do
  # Real threads need real commits.
  self.use_transactional_tests = false

  after do
    Attendance.delete_all
    Event.delete_all
    Attendee.delete_all
    User.delete_all
  end

  it "never records attendance once the close has committed" do
    admin = create(:admin)
    recorded_after_close = 0

    25.times do
      event = create(:event, :open)
      attendee = create(:attendee)

      start = Queue.new
      threads = [
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            start.pop
            described_class.call(event: Event.find(event.id), qr_payload: attendee.qr_payload, operator: admin)
          end
        end,
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            start.pop
            CloseEvent.call(event: Event.find(event.id), user: admin)
          end
        end
      ]
      2.times { start << true }
      threads.each(&:join)

      event.reload
      # Whatever the interleaving, a closed event must never hold an attendance
      # that was written after it closed.
      if event.closed?
        late = event.attendances.where(Attendance.arel_table[:created_at].gt(event.closed_at))
        recorded_after_close += late.count
      end
      Attendance.delete_all
    end

    expect(recorded_after_close).to eq(0)
  end
end
