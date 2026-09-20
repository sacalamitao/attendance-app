class User < ApplicationRecord
  ROLES = %w[admin operator].freeze

  # Registration is intentionally disabled: accounts are provisioned by an
  # administrator (seeds/console), not self-service sign-up.
  devise :database_authenticatable, :recoverable, :rememberable, :validatable, :lockable

  has_many :recorded_attendances, class_name: "Attendance", foreign_key: :operator_id, inverse_of: :operator, dependent: :restrict_with_error

  enum :role, ROLES.index_by(&:itself), default: "operator", validate: true

  validates :name, presence: true

  def display_name
    name.presence || email
  end
end
