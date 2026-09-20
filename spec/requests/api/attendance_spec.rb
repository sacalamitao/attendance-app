require "rails_helper"

RSpec.describe "API attendance", type: :request do
  let(:operator) { create(:user) }
  let(:event) { create(:event, :open) }
  let(:attendee) { create(:attendee, :yan, full_name: "John Doe") }

  def scan(token, ev = event)
    post api_event_attendance_scan_path(ev), params: { qr_token: token }, as: :json
  end

  describe "POST /api/events/:id/attendance/scan" do
    before { sign_in operator }

    it "records attendance and returns attendee + attendance details" do
      scan(attendee.qr_payload)
      expect(response).to have_http_status(:created)
      expect(json["status"]).to eq("recorded")
      expect(json["present_count"]).to eq(1)
      expect(json["attendee"]).to include("id" => attendee.id, "full_name" => "John Doe", "age" => 25, "gender" => "male", "ministry_classification" => "yan", "ministry_label" => "YAN")
      expect(json["attendance"]).to include("id", "scanned_at", "scanned_at_label")
      expect(Attendance.last.operator).to eq(operator)
    end

    it "returns a duplicate result with the original timestamp on a second scan" do
      scan(attendee.qr_payload)
      first_scanned_at = json["attendance"]["scanned_at"]
      travel 2.minutes do
        expect { scan(attendee.qr_payload) }.not_to change(Attendance, :count)
      end
      expect(response).to have_http_status(:ok)
      expect(json["status"]).to eq("duplicate")
      expect(json["message"]).to eq("John Doe is already marked present.")
      expect(json["attendance"]["scanned_at"]).to eq(first_scanned_at)
      expect(json["present_count"]).to eq(1)
    end

    it "rejects unknown tokens with 404 and a machine-readable code" do
      scan("attendee:unknown")
      expect(response).to have_http_status(:not_found)
      expect(json["status"]).to eq("attendee_not_found")
      expect(json["error"]["code"]).to eq("attendee_not_found")
    end

    it "rejects scans for closed and draft events" do
      scan(attendee.qr_payload, create(:event, :closed))
      expect(response).to have_http_status(:unprocessable_content)
      expect(json["status"]).to eq("event_closed")

      scan(attendee.qr_payload, create(:event))
      expect(response).to have_http_status(:unprocessable_content)
      expect(json["status"]).to eq("event_not_open")
      expect(Attendance.count).to eq(0)
    end

    it "rejects inactive attendees" do
      attendee.deactivate!
      scan(attendee.qr_payload)
      expect(response).to have_http_status(:unprocessable_content)
      expect(json["status"]).to eq("attendee_inactive")
    end

    it "ignores a client-supplied operator" do
      post api_event_attendance_scan_path(event), params: { qr_token: attendee.qr_payload, operator_id: create(:admin).id }, as: :json
      expect(Attendance.last.operator).to eq(operator)
    end

    it "returns 404 for an unknown event" do
      scan(attendee.qr_payload, 999_999)
      expect(response).to have_http_status(:not_found)
    end
  end

  it "requires authentication" do
    scan(attendee.qr_payload)
    expect(response).to have_http_status(:unauthorized)
    expect(Attendance.count).to eq(0)
  end

  describe "GET /api/events/:id/attendance and /dashboard" do
    before { sign_in operator }

    it "lists present attendances and dashboard aggregates" do
      present = create(:attendee, :kkb, full_name: "Kid Present")
      create(:attendee, :mens, full_name: "Man Absent")
      create(:attendance, event: event, attendee: present)

      get api_event_attendance_path(event)
      expect(response).to have_http_status(:ok)
      expect(json["attendances"].size).to eq(1)
      expect(json["attendances"].first["attendee"]["full_name"]).to eq("Kid Present")
      expect(json["attendances"].first["ministry_classification"]).to eq("kkb")

      get api_event_attendance_dashboard_path(event)
      expect(response).to have_http_status(:ok)
      expect(json["summary"]).to eq("registered" => 2, "present" => 1, "absent" => 1, "percentage" => 50.0)
      expect(json["ministry_breakdown"].map { |r| r["code"] }).to eq(Ministry::ALL)
      expect(json["absent"]["attendees"].map { |a| a["full_name"] }).to eq([ "Man Absent" ])
    end
  end
end
