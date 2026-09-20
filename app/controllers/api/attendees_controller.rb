module Api
  class AttendeesController < BaseController
    before_action :set_attendee, only: %i[show update destroy qr attendance]

    def index
      authorize Attendee
      scope = policy_scope(Attendee).search(params[:q]).with_gender(params[:gender]).with_current_ministry(params[:ministry])
      scope = params[:status] == "inactive" ? scope.inactive : (params[:status] == "all" ? scope : scope.active)
      pager = paginate(scope.ordered)
      render json: { attendees: pager.records.map { |a| AttendeeSerializer.call(a) }, meta: pager.to_meta }
    end

    def show
      authorize @attendee
      render json: { attendee: AttendeeSerializer.call(@attendee) }
    end

    def create
      attendee = Attendee.new(attendee_params)
      authorize attendee
      if attendee.save
        render json: { attendee: AttendeeSerializer.call(attendee) }, status: :created
      else
        render_validation_errors(attendee)
      end
    end

    def update
      authorize @attendee
      if @attendee.update(attendee_params)
        render json: { attendee: AttendeeSerializer.call(@attendee) }
      else
        render_validation_errors(@attendee)
      end
    end

    def destroy
      authorize @attendee
      @attendee.deactivate!
      render json: { attendee: AttendeeSerializer.call(@attendee) }
    end

    def qr
      authorize @attendee
      render json: {
        attendee_id: @attendee.id,
        payload: @attendee.qr_payload,
        svg_url: qr_attendee_url(@attendee, format: :svg),
        png_url: qr_attendee_url(@attendee, format: :png)
      }
    end

    def attendance
      authorize @attendee
      attendances = @attendee.attendances.includes(:event).joins(:event).merge(Event.ordered)
      render json: {
        attendances: attendances.map do |att|
          AttendanceSerializer.call(att, include_attendee: false).merge(event: EventSerializer.call(att.event, attendance_count: nil))
        end
      }
    end

    private

    def set_attendee
      @attendee = Attendee.find(params[:id])
    end

    def attendee_params
      params.expect(attendee: [ :full_name, :gender, :birthdate ])
    end
  end
end
