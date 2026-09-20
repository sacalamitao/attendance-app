# JSON shape for RecordAttendance results (both successes and errors).
module ScanResultSerializer
  module_function

  def call(result, present_count: nil)
    payload = { status: result.code, message: result.message }
    payload[:present_count] = present_count if present_count

    if result.attendee
      attendee = result.attendee
      reference_date = result.event&.event_date || Date.current
      payload[:attendee] = {
        id: attendee.id,
        full_name: attendee.full_name,
        age: attendee.age(on: reference_date),
        gender: attendee.gender,
        ministry_classification: result.attendance&.ministry_classification || attendee.ministry_on(reference_date),
        ministry_label: Ministry.label(result.attendance&.ministry_classification || attendee.ministry_on(reference_date))
      }
    end

    if result.attendance
      payload[:attendance] = {
        id: result.attendance.id,
        scanned_at: result.attendance.scanned_at,
        scanned_at_label: I18n.l(result.attendance.scanned_at, format: :time)
      }
    end

    payload[:error] = { code: result.code, message: result.message } if result.error?
    payload
  end
end
