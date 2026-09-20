require "rails_helper"

RSpec.describe "Authentication", type: :request do
  it "redirects anonymous users to sign in for HTML pages" do
    get root_path
    expect(response).to redirect_to(new_user_session_path)
    get attendees_path
    expect(response).to redirect_to(new_user_session_path)
    get events_path
    expect(response).to redirect_to(new_user_session_path)
  end

  it "returns 401 JSON for anonymous API requests" do
    get api_attendees_path
    expect(response).to have_http_status(:unauthorized)
    post api_event_attendance_scan_path(create(:event, :open)), params: { qr_token: "x" }, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it "renders the sign-in page and signs a user in" do
    user = create(:admin, password: "password123!")
    get new_user_session_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Church Attendance")

    post user_session_path, params: { user: { email: user.email, password: "password123!" } }
    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response.body).to include("Dashboard")
  end

  it "rejects a wrong password" do
    user = create(:admin, password: "password123!")
    post user_session_path, params: { user: { email: user.email, password: "nope" } }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "signs out" do
    sign_in create(:admin)
    delete destroy_user_session_path
    expect(response).to redirect_to(root_path)
    get root_path
    expect(response).to redirect_to(new_user_session_path)
  end

  it "serves the offline page, manifest and service worker without authentication" do
    get offline_path
    expect(response).to have_http_status(:ok)
    get pwa_manifest_path(format: :json)
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["display"]).to eq("standalone")
    get pwa_service_worker_path(format: :js)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("addEventListener(\"fetch\"")
  end
end
