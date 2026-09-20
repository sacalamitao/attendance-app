# Minimal offset pagination for ActiveRecord scopes.
#
#   pager = Paginator.new(Attendee.ordered, page: params[:page], per_page: 25)
#   pager.records      # => the page of records
#   pager.total_pages  # => 4
class Paginator
  MAX_PER_PAGE = 200

  attr_reader :scope, :page, :per_page

  def initialize(scope, page:, per_page: 25)
    @scope = scope
    @per_page = per_page.to_i.clamp(1, MAX_PER_PAGE)
    @page = [ page.to_i, 1 ].max
  end

  def records
    @records ||= scope.offset(offset).limit(per_page)
  end

  def total_count
    @total_count ||= scope.unscope(:order).count
  end

  def total_pages
    [ (total_count.to_f / per_page).ceil, 1 ].max
  end

  def offset
    (page - 1) * per_page
  end

  def first_index
    total_count.zero? ? 0 : offset + 1
  end

  def last_index
    [ offset + per_page, total_count ].min
  end

  def prev_page
    page > 1 ? page - 1 : nil
  end

  def next_page
    page < total_pages ? page + 1 : nil
  end

  def out_of_range?
    page > total_pages
  end

  def to_meta
    { page: page, per_page: per_page, total_count: total_count, total_pages: total_pages }
  end
end
