# Seguir exige conta ativa e opt-in da pessoa seguida (perfil público ativo).
class FollowPolicy < ApplicationPolicy
  def follow?
    active_user? && record.id != user.id && User.active.where(public_profile: true).exists?(id: record.id)
  end
end
