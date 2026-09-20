require "rails_helper"

RSpec.describe Attendee, type: :model do
  describe "validations" do
    it "is valid with the factory defaults" do
      expect(build(:attendee)).to be_valid
    end

    it "requires full_name, gender and birthdate" do
      attendee = described_class.new
      expect(attendee).not_to be_valid
      expect(attendee.errors[:full_name]).to be_present
      expect(attendee.errors[:gender]).to be_present
      expect(attendee.errors[:birthdate]).to be_present
    end

    it "rejects unsupported gender values" do
      attendee = build(:attendee, gender: "other")
      expect(attendee).not_to be_valid
      expect(attendee.errors[:gender]).to be_present
    end

    it "rejects a birthdate in the future" do
      attendee = build(:attendee, birthdate: Date.current + 1)
      expect(attendee).not_to be_valid
      expect(attendee.errors[:birthdate]).to include("cannot be in the future")
    end

    it "rejects an attendee younger than 13" do
      attendee = build(:attendee, birthdate: Date.current.prev_year(13) + 1)
      expect(attendee).not_to be_valid
      expect(attendee.errors[:birthdate].first).to include("at least 13")
    end

    it "accepts an attendee who turns 13 today" do
      expect(build(:attendee, birthdate: Date.current.prev_year(13))).to be_valid
    end

    it "squishes whitespace in the name" do
      expect(create(:attendee, full_name: "  John   Doe ").full_name).to eq("John Doe")
    end
  end

  describe "QR token" do
    it "is generated automatically and is unique" do
      a = create(:attendee)
      b = create(:attendee)
      expect(a.qr_token).to be_present
      expect(a.qr_token).not_to eq(b.qr_token)
      expect(a.qr_token.length).to be >= 32
    end

    it "is stable across updates" do
      a = create(:attendee)
      token = a.qr_token
      a.update!(full_name: "Renamed")
      expect(a.reload.qr_token).to eq(token)
    end

    it "is enforced unique at the database level" do
      a = create(:attendee)
      expect {
        described_class.insert!({ full_name: "X", gender: "male", birthdate: Date.current.prev_year(20),
                                  qr_token: a.qr_token, created_at: Time.current, updated_at: Time.current })
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "can be regenerated explicitly" do
      a = create(:attendee)
      expect { a.regenerate_qr_token! }.to change { a.reload.qr_token }
    end

    it "encodes an opaque payload and resolves it back" do
      a = create(:attendee)
      expect(a.qr_payload).to eq("attendee:#{a.qr_token}")
      expect(a.qr_payload).not_to include(a.full_name)
      expect(described_class.find_by_qr_payload(a.qr_payload)).to eq(a)
      expect(described_class.find_by_qr_payload(a.qr_token)).to eq(a)
      expect(described_class.find_by_qr_payload("attendee:nope")).to be_nil
      expect(described_class.find_by_qr_payload("")).to be_nil
    end
  end

  describe "ministry classification" do
    it "derives the current ministry from birthdate and gender" do
      expect(build(:attendee, :kkb).current_ministry).to eq(Ministry::KKB)
      expect(build(:attendee, :yan).current_ministry).to eq(Ministry::YAN)
      expect(build(:attendee, :mens).current_ministry).to eq(Ministry::MENS)
      expect(build(:attendee, :womens).current_ministry).to eq(Ministry::WOMENS)
    end

    it "recalculates when birthdate or gender changes" do
      a = create(:attendee, :mens)
      a.update!(gender: Gender::FEMALE)
      expect(a.current_ministry).to eq(Ministry::WOMENS)
      a.update!(birthdate: Date.current.prev_year(20))
      expect(a.current_ministry).to eq(Ministry::KKB)
    end

    it "classifies as of an arbitrary date" do
      a = build(:attendee, birthdate: Date.new(1998, 1, 1), gender: "male")
      expect(a.ministry_on(Date.new(2026, 6, 1))).to eq(Ministry::YAN)
      expect(a.ministry_on(Date.new(2027, 6, 1))).to eq(Ministry::MENS)
    end
  end

  describe ".with_current_ministry" do
    let!(:kkb) { create(:attendee, :kkb) }
    let!(:yan) { create(:attendee, :yan) }
    let!(:mens) { create(:attendee, :mens) }
    let!(:womens) { create(:attendee, :womens) }
    let!(:boundary_kkb) { create(:attendee, birthdate: Date.current.prev_year(22) + 1) } # 21 until tomorrow
    let!(:boundary_yan) { create(:attendee, birthdate: Date.current.prev_year(22)) }     # exactly 22

    it "matches the classifier for every attendee" do
      Ministry::ALL.each do |code|
        expected = described_class.all.select { |a| a.current_ministry == code }
        expect(described_class.with_current_ministry(code)).to match_array(expected)
      end
    end

    it "returns nothing for an unknown ministry and everything for blank" do
      expect(described_class.with_current_ministry("nope")).to be_empty
      expect(described_class.with_current_ministry("").count).to eq(6)
    end
  end

  describe "soft deletion" do
    it "deactivates and reactivates" do
      a = create(:attendee)
      a.deactivate!
      expect(a).not_to be_active
      expect(described_class.active).not_to include(a)
      a.reactivate!
      expect(described_class.active).to include(a)
    end

    it "cannot be hard-deleted while attendance history exists" do
      attendance = create(:attendance)
      expect(attendance.attendee.destroy).to be(false)
      expect(described_class.exists?(attendance.attendee_id)).to be(true)
    end
  end

  describe ".search" do
    it "matches case-insensitively and escapes wildcards" do
      create(:attendee, full_name: "Maria Santos")
      create(:attendee, full_name: "Jose 100%")
      expect(described_class.search("maria").count).to eq(1)
      expect(described_class.search("100%").count).to eq(1)
      expect(described_class.search("  ").count).to eq(2)
    end
  end
end
