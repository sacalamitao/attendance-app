# Aggregates attendance statistics for one event.
#
# "Registered" attendees are every active attendee plus anyone who is present
# at this event (so deactivating someone after they attended never removes
# their attendance). Present attendees use the ministry snapshot stored on the
# attendance row; absent attendees are classified as of the event date so a
# closed event's numbers do not drift as people age.
class EventDashboardQuery
  Summary = Data.define(:registered, :present, :absent, :percentage)
  MinistryRow = Data.define(:code, :label, :registered, :present, :absent, :percentage)

  attr_reader :event

  def initialize(event)
    @event = event
  end

  def summary
    present = attendances.count
    registered = registered_attendees.count
    absent = registered - present
    Summary.new(registered:, present:, absent:, percentage: self.class.percentage(present, registered))
  end

  def ministry_breakdown
    present_by = attendances.group(:ministry_classification).count
    absent_by = absent_counts_by_ministry

    Ministry::ALL.map do |code|
      present = present_by.fetch(code, 0)
      absent = absent_by.fetch(code, 0)
      registered = present + absent
      MinistryRow.new(code:, label: Ministry.label(code), registered:, present:, absent:,
                      percentage: self.class.percentage(present, registered))
    end
  end

  def attendances
    event.attendances
  end

  # Attendances (with attendee preloaded) sorted by most recent scan.
  def present_attendances(search: nil, order: :recent)
    scope = attendances.includes(:attendee, :operator).joins(:attendee).merge(Attendee.search(search))
    order == :name ? scope.merge(Attendee.ordered) : scope.ordered_by_scan
  end

  def absent_attendees(search: nil)
    registered_attendees.where.not(id: attendances.select(:attendee_id)).search(search).ordered
  end

  def registered_attendees
    Attendee.active.or(Attendee.where(id: attendances.select(:attendee_id)))
  end

  def self.percentage(present, registered)
    return 0.0 if registered.to_i.zero?

    (present.to_f * 100 / registered).round(1)
  end

  private

  # One COUNT per ministry using the indexed birthdate windows, rather than
  # loading every absent attendee into Ruby. Classified as of the event date so
  # a closed event's numbers never drift.
  def absent_counts_by_ministry
    base = absent_attendees
    Ministry::ALL.index_with do |code|
      base.with_current_ministry(code, reference_date: event.event_date).count
    end
  end
end
