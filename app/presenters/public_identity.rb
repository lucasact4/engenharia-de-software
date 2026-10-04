# Identifica perfis públicos; contas privadas ou desativadas recebem identidade neutra.
# O id só aparece com opt-in ativo, para montar o link do perfil público.
module PublicIdentity
  module_function

  def for(user, internal: false, with_avatar: false)
    if user&.active? && (user.public_profile? || internal)
      { display_name: user.display_name || user.username || I18n.t("sgu.public_identity.anonymous"),
        username: user.public_profile? ? user.username : nil, public_profile: user.public_profile?,
        id: user.public_profile? ? user.id : nil, avatar_id: with_avatar && user.public_profile? && user.avatar.attached? ? user.id : nil, verified: user.verified? }
    else
      { display_name: I18n.t("sgu.public_identity.anonymous"), username: nil, public_profile: false, id: nil, verified: false }
    end
  end
end
