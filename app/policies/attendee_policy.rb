class AttendeePolicy < ApplicationPolicy
  def index?      = signed_in?
  def show?       = signed_in?
  def qr?         = signed_in?
  def attendance? = signed_in?
  def create?     = admin?
  def update?     = admin?
  def destroy?    = admin?
  def reactivate? = admin?

  class Scope < Scope
    def resolve
      user.present? ? scope.all : scope.none
    end
  end
end
