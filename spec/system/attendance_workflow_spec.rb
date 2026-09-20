require "rails_helper"
require "roo"

# End-to-end happy path through the real HTML pages (rack_test driver, no JS):
# sign in → create attendee → create event → open → scan (API) → dashboard → close → report.
RSpec.describe "Attendance workflow", type: :system do
  before { driven_by(:rack_test) }

  it "runs from login to report download" do
    admin = create(:admin, email: "pastor@example.com", password: "password123!")

    visit new_user_session_path
    fill_in "Email", with: "pastor@example.com"
    fill_in "Password", with: "password123!"
    click_button "Sign in"
    expect(page).to have_content("Dashboard")

    click_link "New attendee", match: :first
    fill_in "Full name", with: "Grace Member"
    select "Female", from: "Gender"
    fill_in "Birthdate", with: Date.current.prev_year(30).iso8601
    click_button "Create attendee"
    expect(page).to have_content("Grace Member")
    expect(page).to have_content("Women's")
    attendee = Attendee.find_by!(full_name: "Grace Member")

    within("nav[aria-label='Main']") { click_link "Events" }
    click_link "New event", match: :first
    fill_in "Event name", with: "System Test Service"
    fill_in "Date", with: Date.current.iso8601
    fill_in "Start time", with: "09:00"
    fill_in "End time", with: "11:00"
    fill_in "Location", with: "Sanctuary"
    click_button "Create event"
    expect(page).to have_content("Draft")
    event = Event.find_by!(name: "System Test Service")

    click_button "Open event"
    expect(page).to have_content("QR Scanner")
    expect(event.reload).to be_open

    # The scanner posts to the JSON API; simulate that here.
    page.driver.post api_event_attendance_scan_path(event), { qr_token: attendee.qr_payload }.to_json,
                     { "CONTENT_TYPE" => "application/json", "ACCEPT" => "application/json" }
    expect(page.driver.status_code).to eq(201)
    expect(JSON.parse(page.driver.response.body)["status"]).to eq("recorded")

    visit dashboard_event_path(event)
    expect(page).to have_content("100%")
    expect(page).to have_content("Grace Member")

    click_button "Close event"
    expect(page).to have_content("Final results")
    expect(event.reload).to be_closed

    click_link "Download report (.xlsx)"
    expect(page.response_headers["Content-Type"]).to include("spreadsheetml")
    path = Rails.root.join("tmp", "system-report.xlsx")
    File.binwrite(path, page.body)
    book = Roo::Excelx.new(path.to_s)
    expect(book.sheet("Attendance Details").row(2)).to eq([ "Grace Member", 30, "Female", "Women's", "Present", book.sheet("Attendance Details").row(2)[5] ])
    File.delete(path)

    expect(admin).to be_admin
  end
end
