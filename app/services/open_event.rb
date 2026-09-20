# Transition an event from draft to open so it can accept attendance scans.
class OpenEvent
  Result = Struct.new(:success?, :event, :error, keyword_init: true)

  def self.call(event:, user:)
    new(event:, user:).call
  end

  def initialize(event:, user:)
    @event = event
    @user = user
  end

  def call
    return failure("You are not allowed to open this event.") unless EventPolicy.new(@user, @event).open?

    @event.with_lock do
      return failure("Only draft events can be opened (event is #{@event.status}).") unless @event.draft?
      return failure(@event.errors.full_messages.to_sentence) unless @event.valid?

      @event.update!(status: :open, opened_at: Time.current)
    end
    Result.new(success?: true, event: @event)
  end

  private

  def failure(message)
    Result.new(success?: false, event: @event, error: message)
  end
end
