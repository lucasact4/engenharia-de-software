# Catálogo administrado somente por administradores. Não há exclusão física: entradas são
# desativadas para preservar o histórico das ocorrências associadas.
class LocationPolicy < ApplicationPolicy
  def menu?
    active_admin?
  end

  def index?
    active_admin?
  end

  def show?
    active_admin?
  end

  def create?
    active_admin?
  end

  def update?
    active_admin?
  end

  def destroy?
    false
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      active_admin? ? scope.all : scope.none
    end
  end
end
