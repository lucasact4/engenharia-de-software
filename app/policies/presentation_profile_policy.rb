class PresentationProfilePolicy < ApplicationPolicy
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

  def activate?
    admin?
  end

  # O perfil ativo alimenta a página pública; troque o padrão antes de removê-lo.
  def destroy?
    admin? && !(record.is_a?(PresentationProfile) && record.active?)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.admin? ? scope.all : scope.none
    end
  end

  private

    def admin?
      user.present? && user.admin?
    end
end
