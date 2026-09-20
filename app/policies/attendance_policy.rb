class AttendancePolicy < ApplicationPolicy
  def index? = signed_in?
  def show?  = signed_in?

  def create?
    signed_in? && EventPolicy.new(user, record.event).scan?
  end

  class Scope < Scope
    def resolve
      user.present? ? scope.all : scope.none
    end
  end
end
