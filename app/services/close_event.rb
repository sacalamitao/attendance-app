# Finalize an event: no further scans are accepted and the report becomes available.
#
# The FOR UPDATE lock taken by +with_lock+ waits for any in-flight
# RecordAttendance transaction (which holds FOR SHARE) to finish, so nothing
# can be recorded after the close commits.
class CloseEvent
  Result = Struct.new(:success?, :event, :error, keyword_init: true)

  def self.call(event:, user:)
    new(event:, user:).call
  end

  def initialize(event:, user:)
    @event = event
    @user = user
  end

  def call
    return failure("You are not allowed to close this event.") unless EventPolicy.new(@user, @event).close?

    @event.with_lock do
      return failure("Only open events can be closed (event is #{@event.status}).") unless @event.open?

      @event.update!(status: :closed, closed_at: Time.current)
    end
    broadcast_refresh
    Result.new(success?: true, event: @event)
  end

  private

  def broadcast_refresh
    Turbo::StreamsChannel.broadcast_refresh_to(@event)
  rescue StandardError => e
    Rails.logger.warn("[CloseEvent] broadcast failed: #{e.class}: #{e.message}")
  end

  def failure(message)
    Result.new(success?: false, event: @event, error: message)
  end
end
