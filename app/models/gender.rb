# Controlled vocabulary for attendee gender.
module Gender
  MALE   = "male"
  FEMALE = "female"

  ALL = [ MALE, FEMALE ].freeze

  LABELS = {
    MALE   => "Male",
    FEMALE => "Female"
  }.freeze

  def self.label(code)
    LABELS.fetch(code.to_s) { code.to_s.titleize }
  end

  def self.valid?(code)
    ALL.include?(code.to_s)
  end
end
