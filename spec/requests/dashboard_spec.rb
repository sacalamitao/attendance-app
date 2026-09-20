require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  it "shows open, upcoming and recent events with stats" do
    sign_in create(:admin)
    create(:event, :open, name: "Live Now")
    create(:event, name: "Next Week", event_date: Date.current + 7)
    closed = create(:event, :closed, name: "Last Week", event_date: Date.current - 7)
    create(:attendance, event: closed)

    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Live Now", "Next Week", "Last Week", "Scan attendance")
  end
end
