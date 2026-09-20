module Api
  class AttendancesController < BaseController
    before_action :set_event

    # Guard against accidental request storms from a misbehaving scanner.
    rate_limit to: 300, within: 1.minute, only: :scan, with: -> {
      render_error(:too_many_requests, "rate_limited", "Too many scans. Please slow down.")
    }

    # POST /api/events/:event_id/attendance/scan  { "qr_token": "attendee:..." }
    def scan
      authorize @event, :record_attendance?
      result = RecordAttendance.call(event: @event, qr_payload: params[:qr_token], operator: current_user)
      render json: ScanResultSerializer.call(result, present_count: @event.attendance_count), status: result.http_status
    end

    # GET /api/events/:event_id/attendance
    def index
      authorize @event, :dashboard?
      query = EventDashboardQuery.new(@event)
      pager = paginate(query.present_attendances(search: params[:q]), per_page: 50)
      render json: { attendances: pager.records.map { |a| AttendanceSerializer.call(a) }, meta: pager.to_meta }
    end

    # GET /api/events/:event_id/attendance/dashboard
    def dashboard
      authorize @event, :dashboard?
      query = EventDashboardQuery.new(@event)
      absent = paginate(query.absent_attendees(search: params[:q]), per_page: 50)
      render json: {
        event: EventSerializer.call(@event),
        summary: query.summary.to_h,
        ministry_breakdown: query.ministry_breakdown.map(&:to_h),
        absent: { attendees: absent.records.map { |a| AttendeeSerializer.call(a, reference_date: @event.event_date) }, meta: absent.to_meta }
      }
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end
  end
end
