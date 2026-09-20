require "rails_helper"
require "roo"

RSpec.describe GenerateEventAttendanceReport do
  let(:event) { create(:event, :closed, name: "Sunday Worship", event_date: Date.new(2026, 6, 7), location: "Main Hall") }
  let!(:present_yan) { create(:attendee, full_name: "Bea Present", gender: "female", birthdate: Date.new(1998, 3, 1)) } # 28 on event date
  let!(:absent_mens) { create(:attendee, full_name: "Abe Absent", gender: "male", birthdate: Date.new(1980, 1, 1)) }
  let!(:present_kkb) { create(:attendee, full_name: "Cal Present", gender: "male", birthdate: Date.new(2010, 5, 5)) }

  before do
    create(:attendance, event: event, attendee: present_yan, scanned_at: Time.zone.local(2026, 6, 7, 9, 4, 32))
    create(:attendance, event: event, attendee: present_kkb, scanned_at: Time.zone.local(2026, 6, 7, 9, 10, 0))
  end

  def open_workbook(report)
    path = Rails.root.join("tmp", "spec-#{SecureRandom.hex(4)}.xlsx")
    File.binwrite(path, report.data)
    Roo::Excelx.new(path.to_s)
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  it "refuses to generate for an event that is not closed" do
    expect { described_class.call(create(:event, :open)) }.to raise_error(described_class::NotFinalized)
  end

  it "produces a real xlsx workbook with two sheets and a sensible filename" do
    report = described_class.call(event)
    expect(report.content_type).to eq(described_class::CONTENT_TYPE)
    expect(report.filename).to eq("sunday-worship-2026-06-07-attendance.xlsx")
    expect(report.data[0, 2]).to eq("PK") # zip container, not CSV

    book = open_workbook(report)
    expect(book.sheets).to eq([ "Event Summary", "Attendance Details" ])
  end

  it "includes event information, totals and the ministry summary" do
    book = open_workbook(described_class.call(event))
    sheet = book.sheet("Event Summary")
    rows = (1..sheet.last_row).map { |r| sheet.row(r) }
    labels = rows.to_h { |r| [ r[0], r[1] ] }

    expect(labels["Event name"]).to eq("Sunday Worship")
    expect(labels["Event date"]).to eq("Sunday, June 7, 2026")
    expect(labels["Start time"]).to eq("9:00 AM")
    expect(labels["End time"]).to eq("11:00 AM")
    expect(labels["Location"]).to eq("Main Hall")
    expect(labels["Total registered attendees"]).to eq(3)
    expect(labels["Total present"]).to eq(2)
    expect(labels["Total absent"]).to eq(1)
    expect(labels["Attendance percentage"]).to be_within(0.0001).of(0.667)

    header_index = rows.index { |r| r[0] == "Ministry" }
    ministry_rows = rows[(header_index + 1)..].to_h { |r| [ r[0], r[1..4] ] }
    expect(ministry_rows["KKB"]).to eq([ 1, 1, 0, 1.0 ])
    expect(ministry_rows["YAN"]).to eq([ 1, 1, 0, 1.0 ])
    expect(ministry_rows["Men's"]).to eq([ 1, 0, 1, 0.0 ])
    expect(ministry_rows["Women's"]).to eq([ 0, 0, 0, 0.0 ])
  end

  it "lists every registered attendee sorted by name with status and scan time" do
    book = open_workbook(described_class.call(event))
    sheet = book.sheet("Attendance Details")
    expect(sheet.row(1)).to eq([ "Full Name", "Age", "Gender", "Ministry Classification", "Attendance Status", "Date/Time Scanned" ])
    expect(sheet.row(2)).to eq([ "Abe Absent", 46, "Male", "Men's", "Absent", nil ])
    expect(sheet.row(3)).to eq([ "Bea Present", 28, "Female", "YAN", "Present", "Jun 7, 2026 9:04 AM" ])
    expect(sheet.row(4)).to eq([ "Cal Present", 16, "Male", "KKB", "Present", "Jun 7, 2026 9:10 AM" ])
    expect(sheet.last_row).to eq(4)
  end

  it "uses the historical ministry snapshot rather than the attendee's current age" do
    Attendance.find_by(attendee: present_yan).update_column(:ministry_classification, "yan")
    present_yan.update!(birthdate: Date.new(1970, 1, 1)) # now Women's
    book = open_workbook(described_class.call(event))
    sheet = book.sheet("Attendance Details")
    bea = (2..sheet.last_row).map { |r| sheet.row(r) }.find { |r| r[0] == "Bea Present" }
    expect(bea[3]).to eq("YAN")
  end

  it "excludes attendees deactivated before the event from absentees but keeps deactivated present ones" do
    create(:attendee, :inactive, full_name: "Zed Gone")
    present_kkb.deactivate!
    book = open_workbook(described_class.call(event))
    names = (2..book.sheet("Attendance Details").last_row).map { |r| book.sheet("Attendance Details").row(r)[0] }
    expect(names).to eq([ "Abe Absent", "Bea Present", "Cal Present" ])
  end
end
