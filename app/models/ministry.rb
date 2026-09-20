# Controlled vocabulary of ministry classifications.
#
# Codes are what gets persisted (attendances.ministry_classification) and
# labels are what humans see. Add new ministries here (and to the DB check
# constraint) so every layer stays in sync.
module Ministry
  KKB    = "kkb"
  YAN    = "yan"
  MENS   = "mens"
  WOMENS = "womens"

  ALL = [ KKB, YAN, MENS, WOMENS ].freeze

  LABELS = {
    KKB    => "KKB",
    YAN    => "YAN",
    MENS   => "Men's",
    WOMENS => "Women's"
  }.freeze

  def self.label(code)
    LABELS.fetch(code.to_s) { code.to_s.titleize }
  end

  def self.valid?(code)
    ALL.include?(code.to_s)
  end
end
