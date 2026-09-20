require "rails_helper"

RSpec.describe ReopenEvent do
  let(:admin) { create(:admin, password: "correct-password") }

  it "reopens a closed event after verifying the admin password" do
    event = create(:event, :closed)

    result = described_class.call(event: event, user: admin, password: "correct-password")

    expect(result).to be_success
    expect(event.reload).to be_open
    expect(event.closed_at).to be_nil
    expect(event.opened_at).to be_present
  end

  it "rejects an incorrect password" do
    event = create(:event, :closed)

    result = described_class.call(event: event, user: admin, password: "wrong-password")

    expect(result).not_to be_success
    expect(result.error).to eq("The password you entered is incorrect.")
    expect(event.reload).to be_closed
  end

  it "rejects operators and events that are not closed" do
    closed_event = create(:event, :closed)
    operator = create(:user, password: "correct-password")

    unauthorized = described_class.call(event: closed_event, user: operator, password: "correct-password")
    invalid_state = described_class.call(event: create(:event, :open), user: admin, password: "correct-password")

    expect(unauthorized).not_to be_success
    expect(closed_event.reload).to be_closed
    expect(invalid_state).not_to be_success
    expect(invalid_state.error).to include("Only closed events")
  end
end
