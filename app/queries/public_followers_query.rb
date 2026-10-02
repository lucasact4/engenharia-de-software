# Lista perfis públicos ativos; a contagem inclui seguidores ativos com perfil privado.
class PublicFollowersQuery
  def initialize(user)
    @user = user
  end

  def call
    return User.none unless @user.active? && @user.public_profile?

    User.active.where(public_profile: true)
      .where(id: UserFollow.visible.where(followed_id: @user.id).select(:follower_id))
  end

  def count
    return 0 unless @user.active? && @user.public_profile?

    UserFollow.visible.where(followed_id: @user.id).count
  end
end
