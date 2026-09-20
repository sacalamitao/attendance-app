module Api
  # JSON API used by the PWA scanner/dashboard. Authenticated with the same
  # Devise session as the HTML app; CSRF is enforced through the X-CSRF-Token
  # header (see app/javascript/api.js).
  class BaseController < ActionController::Base
    include Pundit::Authorization

    protect_from_forgery with: :exception
    before_action :authenticate_user!
    after_action :verify_authorized

    rescue_from Pundit::NotAuthorizedError do
      render_error(:forbidden, "forbidden", "You are not allowed to perform that action.")
    end

    rescue_from ActiveRecord::RecordNotFound do
      render_error(:not_found, "not_found", "The requested record does not exist.")
    end

    rescue_from ActionController::ParameterMissing do |e|
      render_error(:bad_request, "bad_request", e.message)
    end

    rescue_from ActionController::InvalidAuthenticityToken do
      render_error(:unprocessable_content, "invalid_csrf_token", "Your session token is invalid. Reload the page and try again.")
    end

    private

    def render_error(status, code, message, details: nil)
      body = { error: { code: code, message: message } }
      body[:error][:details] = details if details
      render json: body, status: status
    end

    def render_validation_errors(record)
      render_error(:unprocessable_content, "validation_failed", record.errors.full_messages.to_sentence, details: record.errors.to_hash(true))
    end

    def paginate(scope, per_page: 25)
      Paginator.new(scope, page: params[:page], per_page: params.fetch(:per_page, per_page))
    end
  end
end
