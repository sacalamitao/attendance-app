class Attendance < ApplicationRecord
  belongs_to :event
  belongs_to :attendee
  belongs_to :operator, class_name: "User", inverse_of: :recorded_attendances

  validates :scanned_at, presence: true
  validates :ministry_classification, presence: true, inclusion: { in: Ministry::ALL }
  # Application-level duplicate check; the DB unique index is the real guarantee.
  validates :attendee_id, uniqueness: { scope: :event_id, message: "is already marked present for this event" }

  scope :ordered_by_scan, -> { order(scanned_at: :desc, id: :desc) }

  def ministry_label
    Ministry.label(ministry_classification)
  end
end
