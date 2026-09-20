module Api
  class ReportsController < BaseController
    # GET /api/events/:event_id/report → .xlsx download
    def show
      event = Event.find(params[:event_id])
      authorize event, :report?
      report = GenerateEventAttendanceReport.call(event)
      send_data report.data, filename: report.filename, type: report.content_type, disposition: "attachment"
    end
  end
end
