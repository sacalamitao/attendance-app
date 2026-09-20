# Records attendance for a scanned QR code. All business rules live here; the
# frontend only displays the result.
#
#   result = RecordAttendance.call(event: event, qr_payload: "attendee:abc", operator: current_user)
#   result.recorded?  # => true when a new attendance row was created
#   result.duplicate? # => true when the attendee was already present
#   result.error?     # => true for every other outcome (see STATUSES)
#
# Concurrency: the event row is locked FOR SHARE for the duration of the
# insert so a scan can never commit after CloseEvent (which locks FOR UPDATE)
# has committed. Duplicates are caught by the (event_id, attendee_id) unique
# index; a RecordNotUnique simply resolves to the existing attendance.
class RecordAttendance
  STATUSES = %i[
    recorded duplicate attendee_not_found attendee_inactive
    event_closed event_not_open unsupported_age unauthorized
  ].freeze

  MESSAGES = {
    recorded:           "Attendance recorded.",
    duplicate:          "%{name} is already marked present.",
    attendee_not_found: "Attendee not found. This QR code is not registered.",
    attendee_inactive:  "%{name} is inactive and cannot be marked present.",
    event_closed:       "Attendance closed. This event is no longer accepting scans.",
    event_not_open:     "This event is not open for attendance yet.",
    unsupported_age:    "%{name} does not fall into a supported ministry age range for this event.",
    unauthorized:       "You are not allowed to record attendance."
  }.freeze

  Result = Struct.new(:status, :attendance, :attendee, :event, keyword_init: true) do
    def recorded?  = status == :recorded
    def duplicate? = status == :duplicate
    def success?   = recorded? || duplicate?
    def error?     = !success?

    # Machine-readable error/status code for API consumers.
    def code = status.to_s

    def message
      format(MESSAGES.fetch(status), name: attendee&.full_name)
    end

    def http_status
      case status
      when :recorded then :created
      when :duplicate then :ok
      when :attendee_not_found then :not_found
      when :unauthorized then :forbidden
      when :event_closed, :event_not_open, :attendee_inactive, :unsupported_age then :unprocessable_content
      else :unprocessable_content
      end
    end
  end

  def self.call(event:, qr_payload:, operator:, scanned_at: Time.current)
    new(event:, qr_payload:, operator:, scanned_at:).call
  end

  def initialize(event:, qr_payload:, operator:, scanned_at: Time.current)
    @event = event
    @qr_payload = qr_payload
    @operator = operator
    @scanned_at = scanned_at
  end

  def call
    return failure(:unauthorized) unless authorized?

    result = Attendance.transaction { record_within_transaction }
    result.tap { |r| after_recorded(r) if r.recorded? }
  rescue ActiveRecord::RecordNotUnique
    # Lost a race with a concurrent scan for the same attendee: the row now exists.
    attendee = Attendee.find_by_qr_payload(@qr_payload)
    existing = attendee && Attendance.where(event_id: @event.id, attendee_id: attendee.id).first
    existing ? duplicate(existing) : failure(:attendee_not_found)
  end

  private

  attr_reader :event, :operator, :scanned_at

  def authorized?
    operator.present? && EventPolicy.new(operator, event).record_attendance?
  end

  def record_within_transaction
    locked_event = Event.lock("FOR SHARE").find(event.id)
    return failure(:event_closed) if locked_event.closed?
    return failure(:event_not_open) unless locked_event.accepting_attendance?

    attendee = Attendee.find_by_qr_payload(@qr_payload)
    return failure(:attendee_not_found) unless attendee
    return failure(:attendee_inactive, attendee:) unless attendee.active?

    if (existing = Attendance.find_by(event_id: locked_event.id, attendee_id: attendee.id))
      return duplicate(existing)
    end

    classification = attendee.ministry_on(locked_event.event_date)
    return failure(:unsupported_age, attendee:) unless classification

    attendance = Attendance.create!(
      event: locked_event,
      attendee: attendee,
      operator: operator,
      scanned_at: scanned_at,
      ministry_classification: classification
    )

    Result.new(status: :recorded, attendance: attendance, attendee: attendee, event: locked_event)
  end

  def after_recorded(_result)
    # Push a Turbo page refresh to every open dashboard for this event.
    Turbo::StreamsChannel.broadcast_refresh_to(event)
  rescue StandardError => e
    Rails.logger.warn("[RecordAttendance] broadcast failed: #{e.class}: #{e.message}")
  end

  def duplicate(attendance)
    Result.new(status: :duplicate, attendance: attendance, attendee: attendance.attendee, event: event)
  end

  def failure(status, attendee: nil)
    Result.new(status: status, attendee: attendee, event: event)
  end
end
