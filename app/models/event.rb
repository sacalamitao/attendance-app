class Event < ApplicationRecord
  STATUSES = %w[draft open closed].freeze

  has_many :attendances, dependent: :restrict_with_error
  has_many :attendees, through: :attendances

  enum :status, STATUSES.index_by(&:itself), default: "draft", validate: true

  validates :name, presence: true, length: { maximum: 160 }
  validates :event_date, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :location, presence: true, length: { maximum: 200 }
  validate :end_time_not_before_start_time

  scope :ordered, -> { order(event_date: :desc, start_time: :desc, id: :desc) }
  scope :upcoming, -> { where(event_date: Date.current..).where.not(status: :closed).order(event_date: :asc, start_time: :asc) }
  scope :recent, -> { where(event_date: ...Date.current).order(event_date: :desc, start_time: :desc) }
  scope :search, ->(term) {
    term = term.to_s.strip
    term.present? ? where("events.name ILIKE :q OR events.location ILIKE :q", q: "%#{sanitize_sql_like(term)}%") : all
  }
  scope :with_status, ->(status) { status.present? ? where(status: status) : all }
  scope :on_date, ->(date) { date.present? ? where(event_date: date) : all }

  # Only an open event accepts attendance scans; enforced again in RecordAttendance.
  def accepting_attendance?
    open?
  end

  def can_open?
    draft? && valid?
  end

  def can_close?
    open?
  end

  # Only closed events have a finalized report available.
  def report_available?
    closed?
  end

  def attendance_count
    attendances.count
  end

  def time_range
    "#{I18n.l(start_time, format: :time)} – #{I18n.l(end_time, format: :time)}"
  end

  private

  def end_time_not_before_start_time
    return if start_time.blank? || end_time.blank?

    errors.add(:end_time, "cannot be earlier than start time") if end_time < start_time
  end
end
