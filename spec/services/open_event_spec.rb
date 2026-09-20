require "rails_helper"

RSpec.describe OpenEvent do
  let(:admin) { create(:admin) }

  it "opens a draft event" do
    event = create(:event)
    result = described_class.call(event: event, user: admin)
    expect(result.success?).to be(true)
    expect(event.reload).to be_open
    expect(event.opened_at).to be_present
  end

  it "refuses to open a closed event" do
    event = create(:event, :closed)
    result = described_class.call(event: event, user: admin)
    expect(result.success?).to be(false)
    expect(result.error).to include("Only draft events")
    expect(event.reload).to be_closed
  end

  it "refuses to open an already open event" do
    event = create(:event, :open)
    expect(described_class.call(event: event, user: admin).success?).to be(false)
  end

  it "refuses to open an event with invalid data" do
    event = create(:event)
    event.update_column(:location, "")
    result = described_class.call(event: event, user: admin)
    expect(result.success?).to be(false)
    expect(result.error).to include("Location")
    expect(event.reload).to be_draft
  end

  it "refuses non-admin users" do
    event = create(:event)
    result = described_class.call(event: event, user: create(:user))
    expect(result.success?).to be(false)
    expect(event.reload).to be_draft
  end
end
