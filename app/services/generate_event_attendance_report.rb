# Builds the finalized .xlsx attendance workbook for a closed event.
#
#   report = GenerateEventAttendanceReport.call(event)
#   report.filename  # => "sunday-service-2026-09-20-attendance.xlsx"
#   report.data      # => binary xlsx string
#
# Sheet 1 "Event Summary": event details, totals, per-ministry table.
# Sheet 2 "Attendance Details": one row per registered attendee, present
# rows carry the historical ministry snapshot and the scan timestamp.
class GenerateEventAttendanceReport
  CONTENT_TYPE = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet".freeze

  Report = Struct.new(:filename, :data, :content_type, keyword_init: true)

  class NotFinalized < StandardError; end

  def self.call(event, enforce_closed: true)
    new(event, enforce_closed:).call
  end

  def initialize(event, enforce_closed: true)
    @event = event
    @query = EventDashboardQuery.new(event)
    @enforce_closed = enforce_closed
  end

  def call
    raise NotFinalized, "Reports are only available for closed events." if @enforce_closed && !@event.report_available?

    package = Axlsx::Package.new
    package.use_shared_strings = true # better compatibility with Numbers/LibreOffice
    build_summary_sheet(package.workbook)
    build_details_sheet(package.workbook)

    Report.new(filename: filename, data: package.to_stream.read, content_type: CONTENT_TYPE)
  end

  def filename
    "#{@event.name.parameterize.presence || 'event'}-#{@event.event_date.iso8601}-attendance.xlsx"
  end

  private

  def build_summary_sheet(workbook)
    styles = workbook.styles
    title = styles.add_style(b: true, sz: 14)
    bold = styles.add_style(b: true)
    header = styles.add_style(b: true, bg_color: "DDDDDD", border: { style: :thin, color: "999999" })
    percent = styles.add_style(num_fmt: 10) # 0.00%

    summary = @query.summary

    workbook.add_worksheet(name: "Event Summary") do |sheet|
      sheet.add_row [ "Event Attendance Report" ], style: title
      sheet.add_row []
      sheet.add_row [ "Event name", @event.name ], style: [ bold, nil ]
      sheet.add_row [ "Event date", I18n.l(@event.event_date, format: :long_weekday) ], style: [ bold, nil ]
      sheet.add_row [ "Start time", I18n.l(@event.start_time, format: :time) ], style: [ bold, nil ]
      sheet.add_row [ "End time", I18n.l(@event.end_time, format: :time) ], style: [ bold, nil ]
      sheet.add_row [ "Location", @event.location ], style: [ bold, nil ]
      sheet.add_row [ "Status", @event.status.titleize ], style: [ bold, nil ]
      sheet.add_row [ "Closed at", @event.closed_at ? I18n.l(@event.closed_at, format: :short_datetime) : "" ], style: [ bold, nil ]
      sheet.add_row []
      sheet.add_row [ "Total registered attendees", summary.registered ], style: [ bold, nil ]
      sheet.add_row [ "Total present", summary.present ], style: [ bold, nil ]
      sheet.add_row [ "Total absent", summary.absent ], style: [ bold, nil ]
      sheet.add_row [ "Attendance percentage", summary.percentage / 100.0 ], style: [ bold, percent ]
      sheet.add_row []
      sheet.add_row [ "Ministry", "Registered", "Present", "Absent", "Attendance %" ], style: header
      @query.ministry_breakdown.each do |row|
        sheet.add_row [ row.label, row.registered, row.present, row.absent, row.percentage / 100.0 ],
                      style: [ nil, nil, nil, nil, percent ]
      end
      sheet.column_widths 28, 24, 12, 12, 14
    end
  end

  def build_details_sheet(workbook)
    styles = workbook.styles
    header = styles.add_style(b: true, bg_color: "DDDDDD", border: { style: :thin, color: "999999" })

    workbook.add_worksheet(name: "Attendance Details") do |sheet|
      sheet.add_row [ "Full Name", "Age", "Gender", "Ministry Classification", "Attendance Status", "Date/Time Scanned" ], style: header

      detail_rows.each { |row| sheet.add_row row }

      sheet.column_widths 32, 6, 10, 22, 16, 22
      sheet.auto_filter = "A1:F#{detail_rows.size + 1}"
    end
  end

  # Present + absent rows merged and sorted deterministically by name, then id.
  def detail_rows
    @detail_rows ||= begin
      present = @query.present_attendances(order: :name).map do |attendance|
        attendee = attendance.attendee
        [ attendee.full_name, attendee.age(on: @event.event_date), Gender.label(attendee.gender),
          attendance.ministry_label, "Present", I18n.l(attendance.scanned_at, format: :short_datetime), attendee.id ]
      end
      absent = @query.absent_attendees.map do |attendee|
        ministry = attendee.ministry_on(@event.event_date)
        [ attendee.full_name, attendee.age(on: @event.event_date), Gender.label(attendee.gender),
          ministry ? Ministry.label(ministry) : "", "Absent", "", attendee.id ]
      end
      (present + absent).sort_by { |row| [ row[0].downcase, row.last ] }.map { |row| row[0..5] }
    end
  end
end
