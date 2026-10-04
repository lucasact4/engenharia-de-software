# Denúncias são visíveis apenas para quem denunciou e para a administração.
class ContentReportPolicy < ApplicationPolicy
  def menu?
    active_admin?
  end

  def index?
    active_admin?
  end

  def show?
    active_admin? || reporter?
  end

  def review?
    active_admin?
  end

  def reopen?
    reporter? && !record.pending?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless active_user?
      return scope.all if active_admin?

      scope.where(reporter_id: user.id)
    end
  end

  private

    def reporter?
      active_user? && record.reporter_id == user.id
    end
end
