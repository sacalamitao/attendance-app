require "rails_helper"

RSpec.describe MinistryClassifier do
  let(:reference_date) { Date.new(2026, 9, 20) }

  def classify(age, gender: "male")
    described_class.call(birthdate: reference_date.prev_year(age), gender: gender, reference_date: reference_date)
  end

  describe ".call age boundaries" do
    it { expect(classify(12)).to be_nil }
    it { expect(classify(13)).to eq(Ministry::KKB) }
    it { expect(classify(21)).to eq(Ministry::KKB) }
    it { expect(classify(22)).to eq(Ministry::YAN) }
    it { expect(classify(28)).to eq(Ministry::YAN) }
    it { expect(classify(29, gender: "male")).to eq(Ministry::MENS) }
    it { expect(classify(29, gender: "female")).to eq(Ministry::WOMENS) }
    it { expect(classify(85, gender: "female")).to eq(Ministry::WOMENS) }
    it { expect(classify(0)).to be_nil }

    it "ignores gender below 29" do
      expect(classify(15, gender: "female")).to eq(Ministry::KKB)
      expect(classify(25, gender: "female")).to eq(Ministry::YAN)
    end

    it "returns nil for an unknown gender at 29+" do
      expect(classify(40, gender: "other")).to be_nil
    end

    it "returns nil when birthdate is missing" do
      expect(described_class.call(birthdate: nil, gender: "male")).to be_nil
    end
  end

  describe "birthday transitions" do
    let(:birthdate) { Date.new(2004, 9, 20) } # turns 22 on 2026-09-20

    it "is KKB the day before the 22nd birthday" do
      expect(described_class.call(birthdate:, gender: "male", reference_date: Date.new(2026, 9, 19))).to eq(Ministry::KKB)
    end

    it "is YAN on the 22nd birthday" do
      expect(described_class.call(birthdate:, gender: "male", reference_date: Date.new(2026, 9, 20))).to eq(Ministry::YAN)
    end

    it "moves from YAN to Men's on the 29th birthday" do
      born = Date.new(1997, 9, 20)
      expect(described_class.call(birthdate: born, gender: "male", reference_date: Date.new(2026, 9, 19))).to eq(Ministry::YAN)
      expect(described_class.call(birthdate: born, gender: "male", reference_date: Date.new(2026, 9, 20))).to eq(Ministry::MENS)
    end
  end

  describe ".age_on" do
    it "counts whole years, honoring the birthday" do
      born = Date.new(2000, 6, 15)
      expect(described_class.age_on(born, Date.new(2026, 6, 14))).to eq(25)
      expect(described_class.age_on(born, Date.new(2026, 6, 15))).to eq(26)
    end

    it "handles Feb 29 birthdays in non-leap years" do
      born = Date.new(2004, 2, 29)
      expect(described_class.age_on(born, Date.new(2026, 2, 28))).to eq(22)
      expect(described_class.age_on(born, Date.new(2026, 2, 27))).to eq(21)
    end

    it "defaults reference date to today" do
      expect(described_class.age_on(Date.current.prev_year(30))).to eq(30)
    end
  end
end
