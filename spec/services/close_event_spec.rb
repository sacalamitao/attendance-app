require "rails_helper"

RSpec.describe CloseEvent do
  let(:admin) { create(:admin) }

  it "closes an open event and broadcasts a refresh" do
    event = create(:event, :open)
    expect(Turbo::StreamsChannel).to receive(:broadcast_refresh_to).with(event)
    result = described_class.call(event: event, user: admin)
    expect(result.success?).to be(true)
    expect(event.reload).to be_closed
    expect(event.closed_at).to be_present
  end

  it "refuses to close a draft event" do
    event = create(:event)
    expect(described_class.call(event: event, user: admin).success?).to be(false)
    expect(event.reload).to be_draft
  end

  it "refuses to close an already closed event" do
    event = create(:event, :closed)
    expect(described_class.call(event: event, user: admin).success?).to be(false)
  end

  it "refuses non-admin users" do
    event = create(:event, :open)
    expect(described_class.call(event: event, user: create(:user)).success?).to be(false)
    expect(event.reload).to be_open
  end

  it "prevents scans after closing" do
    event = create(:event, :open)
    described_class.call(event: event, user: admin)
    result = RecordAttendance.call(event: event, qr_payload: create(:attendee).qr_payload, operator: admin)
    expect(result.status).to eq(:event_closed)
  end
end
