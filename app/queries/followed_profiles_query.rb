# Perfis que a própria pessoa segue e que continuam públicos e ativos. Vínculos com quem saiu
# do opt-in ou foi desativado ficam guardados e voltam a aparecer se o perfil voltar a ser público.
class FollowedProfilesQuery
  def initialize(viewer)
    @viewer = viewer
  end

  def call
    return User.none unless @viewer&.active?

    User.active.where(public_profile: true)
      .where(id: UserFollow.where(follower_id: @viewer.id).select(:followed_id))
  end
end
