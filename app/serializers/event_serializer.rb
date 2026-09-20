module EventSerializer
  module_function

  def call(event, attendance_count: nil)
    {
      id: event.id,
      name: event.name,
      event_date: event.event_date,
      start_time: event.start_time&.strftime("%H:%M"),
      end_time: event.end_time&.strftime("%H:%M"),
      location: event.location,
      status: event.status,
      opened_at: event.opened_at,
      closed_at: event.closed_at,
      attendance_count: attendance_count || event.attendance_count,
      report_available: event.report_available?,
      created_at: event.created_at,
      updated_at: event.updated_at
    }
  end
end
