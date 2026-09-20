require "rails_helper"

RSpec.describe Event, type: :model do
  it "is valid with factory defaults and starts as draft" do
    event = build(:event)
    expect(event).to be_valid
    expect(event).to be_draft
  end

  it "requires name, date, times and location" do
    event = described_class.new
    expect(event).not_to be_valid
    expect(event.errors.attribute_names).to include(:name, :event_date, :start_time, :end_time, :location)
  end

  it "rejects end time before start time" do
    event = build(:event, start_time: "10:00", end_time: "09:00")
    expect(event).not_to be_valid
    expect(event.errors[:end_time]).to include("cannot be earlier than start time")
  end

  it "rejects invalid statuses" do
    expect(build(:event, status: "bogus")).not_to be_valid
  end

  it "only accepts attendance while open" do
    expect(build(:event)).not_to be_accepting_attendance
    expect(build(:event, :open)).to be_accepting_attendance
    expect(build(:event, :closed)).not_to be_accepting_attendance
  end

  it "only has a report when closed" do
    expect(build(:event, :closed).report_available?).to be(true)
    expect(build(:event, :open).report_available?).to be(false)
  end

  it "counts attendance from attendance records" do
    event = create(:event, :open)
    create_list(:attendance, 2, event: event)
    expect(event.attendance_count).to eq(2)
  end

  describe "database constraints" do
    it "rejects an unknown status" do
      expect { described_class.connection.execute("UPDATE events SET status='x' WHERE id=#{create(:event).id}") }
        .to raise_error(ActiveRecord::StatementInvalid)
    end
  end
end
