# Perfil público: conta ativa com opt-in. Seguir alguém não concede acesso a nada privado.
class PublicProfilePolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    record.is_a?(User) && record.active? && record.public_profile?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.active.where(public_profile: true)
    end
  end
end
