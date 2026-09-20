require "rails_helper"

RSpec.describe "API events", type: :request do
  let(:admin) { create(:admin) }
  let(:operator) { create(:user) }

  it "lists events with attendance counts" do
    sign_in operator
    event = create(:event, :open)
    create_list(:attendance, 3, event: event)
    get api_events_path
    expect(response).to have_http_status(:ok)
    expect(json["events"].first).to include("id" => event.id, "status" => "open", "attendance_count" => 3, "start_time" => "09:00")
  end

  it "lets admins create, update, open and close events" do
    sign_in admin
    post api_events_path, params: { event: { name: "Api Event", event_date: Date.current, start_time: "08:00", end_time: "09:30", location: "Chapel" } }, as: :json
    expect(response).to have_http_status(:created)
    id = json["event"]["id"]
    expect(json["event"]["status"]).to eq("draft")

    patch api_event_path(id), params: { event: { location: "Annex" } }, as: :json
    expect(json["event"]["location"]).to eq("Annex")

    post open_api_event_path(id), as: :json
    expect(response).to have_http_status(:ok)
    expect(json["event"]["status"]).to eq("open")

    post open_api_event_path(id), as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(json["error"]["code"]).to eq("invalid_transition")

    post close_api_event_path(id), as: :json
    expect(json["event"]).to include("status" => "closed", "report_available" => true)

    post open_api_event_path(id), as: :json
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "returns validation errors" do
    sign_in admin
    post api_events_path, params: { event: { name: "", event_date: Date.current, start_time: "10:00", end_time: "09:00", location: "" } }, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(json["error"]["details"].keys).to include("name", "end_time", "location")
  end

  it "forbids operators from managing events" do
    sign_in operator
    event = create(:event)
    post api_events_path, params: { event: { name: "X", event_date: Date.current, start_time: "08:00", end_time: "09:00", location: "L" } }, as: :json
    expect(response).to have_http_status(:forbidden)
    post open_api_event_path(event), as: :json
    expect(response).to have_http_status(:forbidden)
    expect(event.reload).to be_draft
    post close_api_event_path(create(:event, :open)), as: :json
    expect(response).to have_http_status(:forbidden)
  end
end
