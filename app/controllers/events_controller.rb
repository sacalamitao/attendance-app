class EventsController < ApplicationController
  before_action :set_event, only: %i[show edit update open close reopen dashboard scanner report]
  after_action :verify_authorized

  def index
    authorize Event
    scope = policy_scope(Event).search(params[:q]).with_status(params[:status]).on_date(params[:date])
    @pager = paginate(scope.ordered)
    @events = @pager.records
    @attendance_counts = Attendance.where(event_id: @events.map(&:id)).group(:event_id).count
  end

  def show
    authorize @event
    @summary = EventDashboardQuery.new(@event).summary
  end

  def new
    @event = Event.new(event_date: Date.current, start_time: "09:00", end_time: "11:00")
    authorize @event
  end

  def create
    @event = Event.new(event_params)
    authorize @event
    if @event.save
      redirect_to @event, notice: "Event created as a draft. Open it when you are ready to take attendance."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize @event
  end

  def update
    authorize @event
    if @event.update(event_params)
      redirect_to @event, notice: "Event updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def open
    authorize @event
    result = OpenEvent.call(event: @event, user: current_user)
    if result.success?
      redirect_to scanner_event_path(@event), notice: "#{@event.name} is now open for attendance.", status: :see_other
    else
      redirect_to @event, alert: result.error, status: :see_other
    end
  end

  def close
    authorize @event
    result = CloseEvent.call(event: @event, user: current_user)
    if result.success?
      redirect_to dashboard_event_path(@event), notice: "#{@event.name} is closed. Attendance is final and the report is ready.", status: :see_other
    else
      redirect_to @event, alert: result.error, status: :see_other
    end
  end

  def reopen
    authorize @event
    result = ReopenEvent.call(event: @event, user: current_user, password: params[:password])
    if result.success?
      redirect_to scanner_event_path(@event), notice: "#{@event.name} has been reopened and can accept attendance again.", status: :see_other
    else
      redirect_to @event, alert: result.error, status: :see_other
    end
  end

  def dashboard
    authorize @event
    @query = EventDashboardQuery.new(@event)
    @summary = @query.summary
    @breakdown = @query.ministry_breakdown
    @tab = params[:tab] == "absent" ? "absent" : "present"
    list = @tab == "absent" ? @query.absent_attendees(search: params[:q]) : @query.present_attendances(search: params[:q])
    @pager = paginate(list, per_page: 50)
    @rows = @pager.records
  end

  def scanner
    authorize @event
    @present_count = @event.attendance_count
  end

  def report
    authorize @event
    report = GenerateEventAttendanceReport.call(@event)
    send_data report.data, filename: report.filename, type: report.content_type, disposition: "attachment"
  end

  private

  def set_event
    @event = Event.find(params[:id])
  end

  def event_params
    params.expect(event: [ :name, :event_date, :start_time, :end_time, :location ])
  end
end
