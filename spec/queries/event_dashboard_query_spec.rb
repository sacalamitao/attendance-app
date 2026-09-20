require "rails_helper"

RSpec.describe EventDashboardQuery do
  let(:event) { create(:event, :open) }
  let(:query) { described_class.new(event) }

  it "handles an event with no attendees without dividing by zero" do
    summary = query.summary
    expect(summary.registered).to eq(0)
    expect(summary.present).to eq(0)
    expect(summary.absent).to eq(0)
    expect(summary.percentage).to eq(0.0)
    expect(query.ministry_breakdown.map(&:percentage)).to all(eq(0.0))
  end

  context "with a mixed congregation" do
    let!(:kkb_present) { create(:attendee, :kkb, full_name: "Kim KKB") }
    let!(:kkb_absent)  { create(:attendee, :kkb, full_name: "Ken KKB") }
    let!(:yan_present) { create(:attendee, :yan, full_name: "Yara YAN") }
    let!(:mens_absent) { create(:attendee, :mens, full_name: "Mario Mens") }
    let!(:womens_present) { create(:attendee, :womens, full_name: "Wendy Womens") }
    let!(:inactive) { create(:attendee, :inactive, full_name: "Ivan Inactive") }

    before do
      [ kkb_present, yan_present, womens_present ].each do |a|
        create(:attendance, event: event, attendee: a)
      end
    end

    it "computes summary totals and percentage" do
      summary = query.summary
      expect(summary.registered).to eq(5) # inactive excluded
      expect(summary.present).to eq(3)
      expect(summary.absent).to eq(2)
      expect(summary.percentage).to eq(60.0)
    end

    it "breaks down by ministry in a stable order" do
      rows = query.ministry_breakdown.index_by(&:code)
      expect(query.ministry_breakdown.map(&:code)).to eq(Ministry::ALL)
      expect(rows["kkb"].to_h).to include(registered: 2, present: 1, absent: 1, percentage: 50.0)
      expect(rows["yan"].to_h).to include(registered: 1, present: 1, absent: 0, percentage: 100.0)
      expect(rows["mens"].to_h).to include(registered: 1, present: 0, absent: 1, percentage: 0.0)
      expect(rows["womens"].to_h).to include(registered: 1, present: 1, absent: 0, percentage: 100.0)
      expect(rows["mens"].label).to eq("Men's")
    end

    it "lists present attendances and absent attendees" do
      expect(query.present_attendances.map(&:attendee)).to match_array([ kkb_present, yan_present, womens_present ])
      expect(query.absent_attendees).to eq([ kkb_absent, mens_absent ])
    end

    it "searches both lists" do
      expect(query.present_attendances(search: "yara").map(&:attendee)).to eq([ yan_present ])
      expect(query.absent_attendees(search: "mario")).to eq([ mens_absent ])
    end

    it "keeps a deactivated attendee who already attended as present and registered" do
      yan_present.deactivate!
      summary = query.summary
      expect(summary.registered).to eq(5)
      expect(summary.present).to eq(3)
      expect(query.absent_attendees).not_to include(yan_present)
    end

    it "uses the historical classification snapshot for present attendees" do
      Attendance.find_by(attendee: yan_present).update_column(:ministry_classification, "kkb")
      rows = query.ministry_breakdown.index_by(&:code)
      expect(rows["kkb"].present).to eq(2)
      expect(rows["yan"].present).to eq(0)
    end
  end
end
