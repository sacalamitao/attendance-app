require "rails_helper"

RSpec.describe Attendance, type: :model do
  it "is valid with factory defaults" do
    expect(build(:attendance)).to be_valid
  end

  it "requires event, attendee, operator, scanned_at and a valid classification" do
    attendance = described_class.new
    expect(attendance).not_to be_valid
    expect(attendance.errors.attribute_names).to include(:event, :attendee, :operator, :scanned_at, :ministry_classification)
    expect(build(:attendance, ministry_classification: "youth")).not_to be_valid
  end

  it "rejects a duplicate attendee for the same event at the application level" do
    existing = create(:attendance)
    dup = build(:attendance, event: existing.event, attendee: existing.attendee)
    expect(dup).not_to be_valid
    expect(dup.errors[:attendee_id]).to be_present
  end

  it "rejects a duplicate attendee for the same event at the database level" do
    existing = create(:attendance)
    expect {
      described_class.insert!({ event_id: existing.event_id, attendee_id: existing.attendee_id,
                                operator_id: existing.operator_id, scanned_at: Time.current,
                                ministry_classification: "yan", created_at: Time.current, updated_at: Time.current })
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "allows the same attendee at different events" do
    existing = create(:attendance)
    expect(build(:attendance, attendee: existing.attendee)).to be_valid
  end

  it "keeps its classification snapshot when the attendee changes" do
    attendance = create(:attendance, attendee: create(:attendee, :yan))
    expect(attendance.ministry_classification).to eq(Ministry::YAN)
    attendance.attendee.update!(birthdate: Date.current.prev_year(45))
    expect(attendance.reload.ministry_classification).to eq(Ministry::YAN)
    expect(attendance.attendee.current_ministry).to eq(Ministry::MENS)
  end
end
