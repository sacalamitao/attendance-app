require "rails_helper"

RSpec.describe "policies" do
  let(:admin) { build(:admin) }
  let(:operator) { build(:user) }
  let(:attendee) { build(:attendee) }
  let(:open_event) { build(:event, :open) }
  let(:closed_event) { build(:event, :closed) }
  let(:draft_event) { build(:event) }

  describe AttendeePolicy do
    it "lets admins manage and everyone signed in read" do
      expect(described_class.new(admin, attendee)).to have_attributes(index?: true, show?: true, create?: true, update?: true, destroy?: true, reactivate?: true, qr?: true)
      expect(described_class.new(operator, attendee)).to have_attributes(index?: true, show?: true, qr?: true, create?: false, update?: false, destroy?: false, reactivate?: false)
      expect(described_class.new(nil, attendee)).to have_attributes(index?: false, show?: false, create?: false)
    end
  end

  describe EventPolicy do
    it "restricts lifecycle and reports to admins" do
      expect(described_class.new(admin, draft_event)).to have_attributes(create?: true, update?: true, open?: true, close?: true, reopen?: true, report?: false)
      expect(described_class.new(admin, closed_event).report?).to be(true)
      expect(described_class.new(operator, draft_event)).to have_attributes(create?: false, update?: false, open?: false, close?: false, reopen?: false, report?: false)
      expect(described_class.new(operator, closed_event).report?).to be(false)
    end

    it "lets any signed-in user scan an open event only" do
      expect(described_class.new(operator, open_event).scan?).to be(true)
      expect(described_class.new(admin, open_event).scan?).to be(true)
      expect(described_class.new(operator, draft_event).scan?).to be(false)
      expect(described_class.new(operator, closed_event).scan?).to be(false)
      expect(described_class.new(nil, open_event).scan?).to be(false)
      expect(described_class.new(operator, closed_event).record_attendance?).to be(true)
      expect(described_class.new(nil, closed_event).record_attendance?).to be(false)
    end

    it "lets signed-in users view dashboards" do
      expect(described_class.new(operator, closed_event).dashboard?).to be(true)
      expect(described_class.new(nil, closed_event).dashboard?).to be(false)
    end
  end

  describe AttendancePolicy do
    it "delegates create to the event scan rule" do
      expect(described_class.new(operator, build(:attendance, event: open_event)).create?).to be(true)
      expect(described_class.new(operator, build(:attendance, event: closed_event)).create?).to be(false)
      expect(described_class.new(nil, build(:attendance, event: open_event)).create?).to be(false)
    end
  end
end
