require "rails_helper"

RSpec.describe "Attendees (HTML)", type: :request do
  let(:admin) { create(:admin) }
  let(:operator) { create(:user) }

  describe "index" do
    before { sign_in admin }

    it "lists attendees with age, gender, ministry and status" do
      create(:attendee, :kkb, full_name: "Kim Young")
      create(:attendee, :womens, full_name: "Wendy Elder")
      get attendees_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Kim Young", "Wendy Elder", "KKB", "Women&#39;s")
    end

    it "filters by search, ministry, gender and status" do
      create(:attendee, :kkb, full_name: "Kim Young")
      create(:attendee, :mens, full_name: "Mark Elder")
      create(:attendee, :inactive, full_name: "Gone Person")

      get attendees_path, params: { q: "kim" }
      expect(response.body).to include("Kim Young")
      expect(response.body).not_to include("Mark Elder")

      get attendees_path, params: { ministry: "mens" }
      expect(response.body).to include("Mark Elder")
      expect(response.body).not_to include("Kim Young")

      get attendees_path, params: { gender: "female" }
      expect(response.body).not_to include("Mark Elder")

      get attendees_path
      expect(response.body).not_to include("Gone Person")
      get attendees_path, params: { status: "inactive" }
      expect(response.body).to include("Gone Person")
    end

    it "paginates" do
      create_list(:attendee, 30)
      get attendees_path
      expect(response.body).to include("Page 1 of 2")
      get attendees_path, params: { page: 2 }
      expect(response.body).to include("Page 2 of 2")
    end
  end

  describe "create / update / deactivate as admin" do
    before { sign_in admin }

    it "creates an attendee and shows the automatic classification" do
      expect {
        post attendees_path, params: { attendee: { full_name: "New Person", gender: "female", birthdate: Date.current.prev_year(24) } }
      }.to change(Attendee, :count).by(1)
      follow_redirect!
      expect(response.body).to include("New Person", "YAN")
      expect(Attendee.last.qr_token).to be_present
    end

    it "shows validation errors" do
      post attendees_path, params: { attendee: { full_name: "", gender: "male", birthdate: Date.current + 1 } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("cannot be in the future")
    end

    it "ignores a submitted ministry classification" do
      post attendees_path, params: { attendee: { full_name: "Sneaky", gender: "male", birthdate: Date.current.prev_year(16), ministry: "mens" } }
      expect(Attendee.last.current_ministry).to eq(Ministry::KKB)
    end

    it "updates and recalculates the current ministry without touching history" do
      attendee = create(:attendee, :yan)
      attendance = create(:attendance, attendee: attendee)
      patch attendee_path(attendee), params: { attendee: { birthdate: Date.current.prev_year(50) } }
      follow_redirect!
      expect(response.body).to include("Men&#39;s")
      expect(attendance.reload.ministry_classification).to eq(Ministry::YAN)
    end

    it "deactivates instead of deleting and can reactivate" do
      attendance = create(:attendance)
      attendee = attendance.attendee
      delete attendee_path(attendee)
      expect(response).to redirect_to(attendees_path)
      expect(attendee.reload).not_to be_active
      expect(Attendance.exists?(attendance.id)).to be(true)

      post reactivate_attendee_path(attendee)
      expect(attendee.reload).to be_active
    end

    it "renders the show page with QR code and attendance history" do
      attendance = create(:attendance)
      get attendee_path(attendance.attendee)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<svg", attendance.event.name)
      expect(response.body).not_to include(attendance.attendee.full_name + attendance.attendee.qr_token) # sanity
    end

    it "serves the QR code as SVG and PNG containing only the token" do
      attendee = create(:attendee)
      get qr_attendee_path(attendee, format: :svg)
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("image/svg+xml")
      get qr_attendee_path(attendee, format: :png, download: 1)
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("image/png")
      expect(response.headers["Content-Disposition"]).to include("attachment")
    end
  end

  describe "as operator" do
    before { sign_in operator }

    it "can view but not manage" do
      attendee = create(:attendee)
      get attendees_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("New attendee")
      get attendee_path(attendee)
      expect(response).to have_http_status(:ok)

      get new_attendee_path
      expect(response).to redirect_to(root_path)
      expect { post attendees_path, params: { attendee: { full_name: "X", gender: "male", birthdate: Date.current.prev_year(20) } } }.not_to change(Attendee, :count)
      patch attendee_path(attendee), params: { attendee: { full_name: "Changed" } }
      expect(attendee.reload.full_name).not_to eq("Changed")
      delete attendee_path(attendee)
      expect(attendee.reload).to be_active
    end
  end
end
