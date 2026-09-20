require "rails_helper"

RSpec.describe "API attendees", type: :request do
  let(:admin) { create(:admin) }
  let(:operator) { create(:user) }

  describe "GET /api/attendees" do
    before { sign_in operator }

    it "lists active attendees with derived fields and pagination meta" do
      create(:attendee, :yan, full_name: "Yara")
      create(:attendee, :inactive)
      get api_attendees_path
      expect(response).to have_http_status(:ok)
      expect(json["attendees"].size).to eq(1)
      expect(json["attendees"].first).to include("full_name" => "Yara", "ministry_classification" => "yan", "ministry_label" => "YAN", "age" => 25, "active" => true)
      expect(json["attendees"].first.keys).not_to include("qr_token")
      expect(json["meta"]).to include("page" => 1, "total_count" => 1)
    end

    it "filters by ministry" do
      create(:attendee, :kkb)
      create(:attendee, :mens)
      get api_attendees_path, params: { ministry: "kkb" }
      expect(json["attendees"].map { |a| a["ministry_classification"] }).to eq([ "kkb" ])
    end
  end

  describe "admin writes" do
    before { sign_in admin }

    it "creates, updates and deactivates" do
      post api_attendees_path, params: { attendee: { full_name: "Api Person", gender: "male", birthdate: Date.current.prev_year(30) } }, as: :json
      expect(response).to have_http_status(:created)
      id = json["attendee"]["id"]
      expect(json["attendee"]["ministry_classification"]).to eq("mens")

      patch api_attendee_path(id), params: { attendee: { gender: "female" } }, as: :json
      expect(response).to have_http_status(:ok)
      expect(json["attendee"]["ministry_classification"]).to eq("womens")

      delete api_attendee_path(id), as: :json
      expect(response).to have_http_status(:ok)
      expect(json["attendee"]["active"]).to be(false)
      expect(Attendee.exists?(id)).to be(true)
    end

    it "returns structured validation errors" do
      post api_attendees_path, params: { attendee: { full_name: "", gender: "x", birthdate: Date.current.prev_year(5) } }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]["code"]).to eq("validation_failed")
      expect(json["error"]["details"].keys).to include("full_name", "gender", "birthdate")
    end

    it "returns 400 for a missing payload and 404 for unknown ids" do
      post api_attendees_path, params: {}, as: :json
      expect(response).to have_http_status(:bad_request)
      get api_attendee_path(999_999)
      expect(response).to have_http_status(:not_found)
      expect(json["error"]["code"]).to eq("not_found")
    end

    it "exposes the QR payload and attendance history" do
      attendance = create(:attendance)
      attendee = attendance.attendee
      get qr_api_attendee_path(attendee)
      expect(json["payload"]).to eq(attendee.qr_payload)
      expect(json["svg_url"]).to include("/attendees/#{attendee.id}/qr.svg")

      get attendance_api_attendee_path(attendee)
      expect(json["attendances"].size).to eq(1)
      expect(json["attendances"].first["event"]["id"]).to eq(attendance.event_id)
    end
  end

  describe "operator writes" do
    before { sign_in operator }

    it "are forbidden" do
      post api_attendees_path, params: { attendee: { full_name: "X", gender: "male", birthdate: Date.current.prev_year(30) } }, as: :json
      expect(response).to have_http_status(:forbidden)
      expect(json["error"]["code"]).to eq("forbidden")
      attendee = create(:attendee)
      patch api_attendee_path(attendee), params: { attendee: { full_name: "Y" } }, as: :json
      expect(response).to have_http_status(:forbidden)
      delete api_attendee_path(attendee), as: :json
      expect(response).to have_http_status(:forbidden)
      expect(attendee.reload).to be_active
    end
  end

  describe "GET /api/classification" do
    before { sign_in operator }

    it "previews the classification from the backend rules" do
      get api_classification_path, params: { birthdate: Date.current.prev_year(24).iso8601, gender: "female" }
      expect(json).to include("ministry_classification" => "yan", "ministry_label" => "YAN", "age" => 24, "error" => nil)

      get api_classification_path, params: { birthdate: Date.current.prev_year(10).iso8601, gender: "male" }
      expect(json["ministry_classification"]).to be_nil
      expect(json["error"]).to include("at least 13")

      get api_classification_path, params: { birthdate: "not-a-date", gender: "male" }
      expect(json["error"]).to include("valid birthdate")
    end
  end
end
