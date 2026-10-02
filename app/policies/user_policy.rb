# Administração de contas, permitida somente a administradores ativos.
class UserPolicy < ApplicationPolicy
  def menu?
    admin?
  end

  def index?
    admin?
  end

  def show?
    admin?
  end

  def create?
    admin?
  end

  def update?
    admin?
  end

  def destroy?
    admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless active_admin?

      scope.where(deleted_at: nil)
    end
  end

  private

    def admin?
      active_admin?
    end
end
