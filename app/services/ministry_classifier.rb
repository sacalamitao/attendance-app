# The single source of truth for ministry classification rules.
#
#   Age 13–21       → KKB
#   Age 22–28       → YAN
#   Age 29+ male    → Men's
#   Age 29+ female  → Women's
#
# Ages below MINIMUM_AGE are unsupported and yield +nil+ so callers can
# surface a clear validation error instead of silently classifying.
#
#   MinistryClassifier.call(birthdate: Date.new(2000, 1, 1), gender: "male")
#   # => "yan"
class MinistryClassifier
  MINIMUM_AGE = 13

  # Ordered rules: the first rule whose age range and gender match wins.
  # Gender +nil+ means "any gender".
  RULES = [
    { range: (13..21),         gender: nil,           ministry: Ministry::KKB },
    { range: (22..28),         gender: nil,           ministry: Ministry::YAN },
    { range: (29..Float::INFINITY), gender: Gender::MALE,   ministry: Ministry::MENS },
    { range: (29..Float::INFINITY), gender: Gender::FEMALE, ministry: Ministry::WOMENS }
  ].freeze

  def self.call(birthdate:, gender:, reference_date: Date.current)
    new(birthdate:, gender:, reference_date:).call
  end

  # Whole years between +birthdate+ and +reference_date+, honoring the
  # actual birthday (someone born 2000-06-15 is 25 on 2026-06-14 and 26 on 2026-06-15).
  def self.age_on(birthdate, reference_date = Date.current)
    return nil if birthdate.blank? || reference_date.blank?

    birthdate = birthdate.to_date
    reference_date = reference_date.to_date
    age = reference_date.year - birthdate.year
    # Date#>> shifts by months and clamps Feb 29 to Feb 28 in non-leap years.
    birthday_this_year = birthdate >> (12 * age)
    age -= 1 if reference_date < birthday_this_year
    age
  end

  def self.supported_age?(age)
    age.present? && age >= MINIMUM_AGE
  end

  def initialize(birthdate:, gender:, reference_date: Date.current)
    @birthdate = birthdate
    @gender = gender.to_s
    @reference_date = reference_date
  end

  def call
    age = self.class.age_on(@birthdate, @reference_date)
    return nil unless self.class.supported_age?(age)

    rule = RULES.find { |r| r[:range].cover?(age) && (r[:gender].nil? || r[:gender] == @gender) }
    rule&.fetch(:ministry)
  end
end
