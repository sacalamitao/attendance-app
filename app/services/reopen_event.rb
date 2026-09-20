# Reopen a finalized event after re-authenticating the administrator.
class ReopenEvent
  Result = Struct.new(:success?, :event, :error, keyword_init: true)

  def self.call(event:, user:, password:)
    new(event:, user:, password:).call
  end

  def initialize(event:, user:, password:)
    @event = event
    @user = user
    @password = password
  end

  def call
    return failure("You are not allowed to reopen this event.") unless EventPolicy.new(@user, @event).reopen?
    return failure("Enter your current password to reopen this event.") if @password.blank?
    return failure("The password you entered is incorrect.") unless @user.valid_password?(@password)

    @event.with_lock do
      return failure("Only closed events can be reopened (event is #{@event.status}).") unless @event.closed?

      @event.update!(status: :open, closed_at: nil)
    end
    broadcast_refresh
    Result.new(success?: true, event: @event)
  end

  private

  def broadcast_refresh
    Turbo::StreamsChannel.broadcast_refresh_to(@event)
  rescue StandardError => e
    Rails.logger.warn("[ReopenEvent] broadcast failed: #{e.class}: #{e.message}")
  end

  def failure(message)
    Result.new(success?: false, event: @event, error: message)
  end
end
