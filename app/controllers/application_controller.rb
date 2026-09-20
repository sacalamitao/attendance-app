class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :authenticate_user!

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized
    respond_to do |format|
      format.html do
        flash[:alert] = "You are not allowed to perform that action."
        redirect_back_or_to root_path, status: :see_other
      end
      format.json { render json: { error: { code: "forbidden", message: "You are not allowed to perform that action." } }, status: :forbidden }
      format.any { head :forbidden }
    end
  end

  def paginate(scope, per_page: 25)
    Paginator.new(scope, page: params[:page], per_page: per_page)
  end
end
