require "rails_helper"

RSpec.describe "API reports", type: :request do
  it "downloads the xlsx for a closed event as admin" do
    sign_in create(:admin)
    event = create(:event, :closed)
    get api_event_report_path(event)
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq(GenerateEventAttendanceReport::CONTENT_TYPE)
    expect(response.body[0, 2]).to eq("PK")
  end

  it "refuses reports for events that are not closed" do
    sign_in create(:admin)
    get api_event_report_path(create(:event, :open))
    expect(response).to have_http_status(:forbidden)
  end

  it "refuses operators" do
    sign_in create(:user)
    get api_event_report_path(create(:event, :closed))
    expect(response).to have_http_status(:forbidden)
    expect(json["error"]["code"]).to eq("forbidden")
  end

  it "requires authentication" do
    get api_event_report_path(create(:event, :closed))
    expect(response).to have_http_status(:unauthorized)
  end
end
