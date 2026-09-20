class AttendeesController < ApplicationController
  before_action :set_attendee, only: %i[show edit update destroy reactivate qr]
  after_action :verify_authorized

  def index
    authorize Attendee
    scope = policy_scope(Attendee)
      .search(params[:q])
      .with_gender(params[:gender])
      .with_current_ministry(params[:ministry])
    scope = params[:status] == "inactive" ? scope.inactive : (params[:status] == "all" ? scope : scope.active)
    @pager = paginate(scope.ordered)
    @attendees = @pager.records
  end

  def show
    authorize @attendee
    @attendances = @attendee.attendances.includes(:event).joins(:event).merge(Event.ordered).limit(50)
  end

  def new
    @attendee = Attendee.new
    authorize @attendee
  end

  def create
    @attendee = Attendee.new(attendee_params)
    authorize @attendee
    if @attendee.save
      redirect_to @attendee, notice: "#{@attendee.full_name} was added and classified as #{@attendee.current_ministry_label}."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize @attendee
  end

  def update
    authorize @attendee
    if @attendee.update(attendee_params)
      redirect_to @attendee, notice: "Attendee updated. Current ministry: #{@attendee.current_ministry_label}."
    else
      render :edit, status: :unprocessable_content
    end
  end

  # Soft delete: attendance history must stay intact.
  def destroy
    authorize @attendee
    @attendee.deactivate!
    redirect_to attendees_path, notice: "#{@attendee.full_name} was deactivated. Their attendance history is preserved.", status: :see_other
  end

  def reactivate
    authorize @attendee
    @attendee.reactivate!
    redirect_to @attendee, notice: "#{@attendee.full_name} was reactivated.", status: :see_other
  end

  # Downloadable QR code (SVG or PNG). The payload is an opaque token only.
  def qr
    authorize @attendee
    code = RQRCode::QRCode.new(@attendee.qr_payload)
    respond_to do |format|
      format.svg do
        send_data code.as_svg(module_size: 8, standalone: true, use_path: true),
                  type: "image/svg+xml", disposition: disposition("svg")
      end
      format.png do
        send_data code.as_png(size: 600, border_modules: 2).to_s,
                  type: "image/png", disposition: disposition("png")
      end
      format.any { head :not_acceptable }
    end
  end

  private

  def set_attendee
    @attendee = Attendee.find(params[:id])
  end

  def attendee_params
    params.expect(attendee: [ :full_name, :gender, :birthdate ])
  end

  def disposition(ext)
    filename = "#{@attendee.full_name.parameterize}-qr.#{ext}"
    params[:download].present? ? "attachment; filename=\"#{filename}\"" : "inline"
  end
end
