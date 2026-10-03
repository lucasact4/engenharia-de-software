# Edição do próprio perfil (record = conta da sessão). Não usa UserPolicy, que é administrativa.
class ProfilePolicy < ApplicationPolicy
  def show?
    own?
  end

  def update?
    own?
  end

  private

    def own?
      active_user? && record.is_a?(User) && record.id == user.id
    end
end
