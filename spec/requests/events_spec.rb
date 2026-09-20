require "rails_helper"

RSpec.describe "Events (HTML)", type: :request do
  let(:admin) { create(:admin) }
  let(:operator) { create(:user) }

  describe "as admin" do
    before { sign_in admin }

    it "lists events with attendance counts and filters" do
      open_event = create(:event, :open, name: "Open Service")
      create(:event, :closed, name: "Old Service", event_date: Date.current - 10)
      create_list(:attendance, 2, event: open_event)

      get events_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Open Service", "Old Service")

      get events_path, params: { status: "closed" }
      expect(response.body).to include("Old Service")
      expect(response.body).not_to include("Open Service")

      get events_path, params: { q: "open" }
      expect(response.body).to include("Open Service")
      expect(response.body).not_to include("Old Service")

      get events_path, params: { date: Date.current.iso8601 }
      expect(response.body).to include("Open Service")
      expect(response.body).not_to include("Old Service")
    end

    it "creates a draft event" do
      expect {
        post events_path, params: { event: { name: "New Event", event_date: Date.current, start_time: "09:00", end_time: "10:00", location: "Hall" } }
      }.to change(Event, :count).by(1)
      expect(Event.last).to be_draft
      follow_redirect!
      expect(response.body).to include("Open event")
    end

    it "rejects invalid events" do
      post events_path, params: { event: { name: "", event_date: Date.current, start_time: "10:00", end_time: "09:00", location: "" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("cannot be earlier than start time")
    end

    it "opens a draft event and redirects to the scanner" do
      event = create(:event)
      post open_event_path(event)
      expect(response).to redirect_to(scanner_event_path(event))
      expect(event.reload).to be_open
    end

    it "does not allow opening a closed event or closing a draft event" do
      closed = create(:event, :closed)
      post open_event_path(closed)
      expect(response).to redirect_to(event_path(closed))
      expect(closed.reload).to be_closed
      expect(flash[:alert]).to include("Only draft events")

      draft = create(:event)
      post close_event_path(draft)
      expect(draft.reload).to be_draft
    end

    it "closes an open event and offers the report" do
      event = create(:event, :open)
      post close_event_path(event)
      expect(response).to redirect_to(dashboard_event_path(event))
      expect(event.reload).to be_closed
      follow_redirect!
      expect(response.body).to include("Download report")
    end

    it "reopens a closed event only after confirming the admin password" do
      event = create(:event, :closed)

      post reopen_event_path(event), params: { password: "wrong" }
      expect(event.reload).to be_closed
      expect(flash[:alert]).to include("incorrect")

      post reopen_event_path(event), params: { password: admin.password }
      expect(response).to redirect_to(scanner_event_path(event))
      expect(event.reload).to be_open
      expect(event.closed_at).to be_nil
    end

    it "shows the scanner page for an open event" do
      event = create(:event, :open)
      get scanner_event_path(event)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("data-controller=\"qr-scanner\"", api_event_attendance_scan_path(event))
    end

    it "does not show the scanner for a closed event" do
      get scanner_event_path(create(:event, :closed))
      expect(response).to redirect_to(root_path)
    end

    it "renders the dashboard with summary, breakdown and lists" do
      event = create(:event, :open)
      present = create(:attendee, :kkb, full_name: "Present Kid")
      absent = create(:attendee, :womens, full_name: "Absent Lady")
      create(:attendance, event: event, attendee: present)

      get dashboard_event_path(event)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Present Kid", "Ministry breakdown", "50%")
      expect(response.body).not_to include("Absent Lady")

      get dashboard_event_path(event, tab: "absent")
      expect(response.body).to include("Absent Lady")
      expect(response.body).not_to include("Present Kid")

      get dashboard_event_path(event, tab: "absent", q: "nobody")
      expect(response.body).to include("No absent attendees")
      expect(absent).to be_present
    end

    it "downloads the xlsx report for a closed event only" do
      event = create(:event, :closed, name: "Final")
      get report_event_path(event)
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq(GenerateEventAttendanceReport::CONTENT_TYPE)
      expect(response.headers["Content-Disposition"]).to include("final-")
      expect(response.body[0, 2]).to eq("PK")

      get report_event_path(create(:event, :open))
      expect(response).to redirect_to(root_path)
    end
  end

  describe "as operator" do
    before { sign_in operator }

    it "can view events, dashboards and the scanner but cannot manage them" do
      event = create(:event, :open)
      get events_path
      expect(response).to have_http_status(:ok)
      get event_path(event)
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Close event")
      get dashboard_event_path(event)
      expect(response).to have_http_status(:ok)
      get scanner_event_path(event)
      expect(response).to have_http_status(:ok)

      get new_event_path
      expect(response).to redirect_to(root_path)
      expect { post events_path, params: { event: { name: "X", event_date: Date.current, start_time: "09:00", end_time: "10:00", location: "L" } } }.not_to change(Event, :count)
      post close_event_path(event)
      expect(event.reload).to be_open
      post reopen_event_path(create(:event, :closed)), params: { password: operator.password }
      expect(Event.closed.count).to eq(1)
      post open_event_path(create(:event))
      expect(Event.open.count).to eq(1)
      get report_event_path(create(:event, :closed))
      expect(response).to redirect_to(root_path)
    end
  end
end
