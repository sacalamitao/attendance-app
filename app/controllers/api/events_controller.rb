module Api
  class EventsController < BaseController
    before_action :set_event, only: %i[show update open close]

    def index
      authorize Event
      scope = policy_scope(Event).search(params[:q]).with_status(params[:status]).on_date(params[:date])
      pager = paginate(scope.ordered)
      counts = Attendance.where(event_id: pager.records.map(&:id)).group(:event_id).count
      render json: {
        events: pager.records.map { |e| EventSerializer.call(e, attendance_count: counts.fetch(e.id, 0)) },
        meta: pager.to_meta
      }
    end

    def show
      authorize @event
      render json: { event: EventSerializer.call(@event) }
    end

    def create
      event = Event.new(event_params)
      authorize event
      if event.save
        render json: { event: EventSerializer.call(event) }, status: :created
      else
        render_validation_errors(event)
      end
    end

    def update
      authorize @event
      if @event.update(event_params)
        render json: { event: EventSerializer.call(@event) }
      else
        render_validation_errors(@event)
      end
    end

    def open
      authorize @event
      transition(OpenEvent.call(event: @event, user: current_user))
    end

    def close
      authorize @event
      transition(CloseEvent.call(event: @event, user: current_user))
    end

    private

    def transition(result)
      if result.success?
        render json: { event: EventSerializer.call(result.event) }
      else
        render_error(:unprocessable_content, "invalid_transition", result.error)
      end
    end

    def set_event
      @event = Event.find(params[:id])
    end

    def event_params
      params.expect(event: [ :name, :event_date, :start_time, :end_time, :location ])
    end
  end
end
