module AttendanceSerializer
  module_function

  def call(attendance, include_attendee: true)
    data = {
      id: attendance.id,
      event_id: attendance.event_id,
      attendee_id: attendance.attendee_id,
      operator_id: attendance.operator_id,
      scanned_at: attendance.scanned_at,
      ministry_classification: attendance.ministry_classification,
      ministry_label: attendance.ministry_label
    }
    data[:attendee] = AttendeeSerializer.call(attendance.attendee) if include_attendee
    data
  end
end
