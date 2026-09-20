class DashboardController < ApplicationController
  def show
    events = policy_scope(Event)
    @open_events = events.open.order(event_date: :asc, start_time: :asc)
    @upcoming_events = events.upcoming.where.not(status: :open).limit(5)
    @recent_events = events.closed.ordered.limit(5)
    @stats = {
      attendees: Attendee.active.count,
      events: events.count,
      closed_events: events.closed.count,
      average_attendance: average_attendance(@recent_events)
    }
  end

  private

  def average_attendance(events)
    percentages = events.map { |event| EventDashboardQuery.new(event).summary.percentage }
    return nil if percentages.empty?

    (percentages.sum / percentages.size).round(1)
  end
end
