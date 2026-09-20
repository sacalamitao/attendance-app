class EventPolicy < ApplicationPolicy
  def index?     = signed_in?
  def show?      = signed_in?
  def dashboard? = signed_in?
  def scanner?   = scan?
  def create?    = admin?
  def update?    = admin?
  def open?      = admin?
  def close?     = admin?
  def reopen?    = admin?
  def report?    = admin? && record.report_available?

  # Both admins and operators may record attendance (role check only).
  def record_attendance?
    signed_in?
  end

  # The scanner is only usable while the event is open.
  def scan?
    record_attendance? && record.open?
  end

  class Scope < Scope
    def resolve
      user.present? ? scope.all : scope.none
    end
  end
end
