class Attendee < ApplicationRecord
  QR_PREFIX = "attendee:"

  has_many :attendances, dependent: :restrict_with_error
  has_many :events, through: :attendances

  before_validation :ensure_qr_token
  before_validation :normalize_full_name

  validates :full_name, presence: true, length: { maximum: 120 }
  validates :gender, presence: true, inclusion: { in: Gender::ALL, message: "is not a supported value" }
  validates :qr_token, presence: true, uniqueness: true
  validates :birthdate, presence: true
  validate :birthdate_not_in_future
  validate :birthdate_within_supported_ages

  scope :active, -> { where(deactivated_at: nil) }
  scope :inactive, -> { where.not(deactivated_at: nil) }
  scope :search, ->(term) {
    term = term.to_s.strip
    term.present? ? where("attendees.full_name ILIKE ?", "%#{sanitize_sql_like(term)}%") : all
  }
  scope :with_gender, ->(gender) { gender.present? ? where(gender: gender) : all }
  scope :ordered, -> { order(:full_name, :id) }

  # Resolve a raw QR payload ("attendee:<token>" or a bare token) to an attendee.
  def self.find_by_qr_payload(payload)
    token = extract_qr_token(payload)
    token.present? ? find_by(qr_token: token) : nil
  end

  def self.extract_qr_token(payload)
    value = payload.to_s.strip
    value = value.delete_prefix(QR_PREFIX)
    value.presence
  end

  # Filter by *current* ministry. Ministry is derived, not stored, so we
  # translate the ministry back into a birthdate window (+ gender for 29+).
  def self.with_current_ministry(ministry, reference_date: Date.current)
    return all if ministry.blank?
    return none unless Ministry.valid?(ministry)

    rule = MinistryClassifier::RULES.find { |r| r[:ministry] == ministry }
    min_age = rule[:range].begin
    max_age = rule[:range].end

    # Someone is at least +min_age+ if born on or before reference_date - min_age years.
    latest_birthdate = reference_date.prev_year(min_age)
    scope = where(birthdate: ..latest_birthdate)
    unless max_age.infinite?
      earliest_birthdate = reference_date.prev_year(max_age + 1) + 1
      scope = scope.where(birthdate: earliest_birthdate..)
    end
    scope = scope.where(gender: rule[:gender]) if rule[:gender]
    scope
  end

  def active?
    deactivated_at.nil?
  end

  def deactivate!
    update!(deactivated_at: Time.current) if active?
  end

  def reactivate!
    update!(deactivated_at: nil) unless active?
  end

  def age(on: Date.current)
    MinistryClassifier.age_on(birthdate, on)
  end

  # Ministry classification as of +on+. Returns nil for unsupported ages.
  def ministry_on(on)
    MinistryClassifier.call(birthdate: birthdate, gender: gender, reference_date: on)
  end

  def current_ministry
    ministry_on(Date.current)
  end

  def current_ministry_label
    Ministry.label(current_ministry) if current_ministry
  end

  def qr_payload
    "#{QR_PREFIX}#{qr_token}"
  end

  def regenerate_qr_token!
    update!(qr_token: self.class.generate_qr_token)
  end

  def self.generate_qr_token
    SecureRandom.urlsafe_base64(24)
  end

  private

  def ensure_qr_token
    self.qr_token = self.class.generate_qr_token if qr_token.blank?
  end

  def normalize_full_name
    self.full_name = full_name.to_s.squish if full_name
  end

  def birthdate_not_in_future
    return if birthdate.blank?

    errors.add(:birthdate, "cannot be in the future") if birthdate > Date.current
  end

  def birthdate_within_supported_ages
    return if birthdate.blank? || birthdate > Date.current

    current_age = age
    return if MinistryClassifier.supported_age?(current_age)

    errors.add(:birthdate, "must be for an attendee at least #{MinistryClassifier::MINIMUM_AGE} years old (currently #{current_age})")
  end
end
