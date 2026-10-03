# Identifica perfis públicos; contas privadas ou desativadas recebem identidade neutra.
# O id só aparece com opt-in ativo, para montar o link do perfil público.
module PublicIdentity
  module_function

  def for(user)
    if user&.active? && user.public_profile?
      { display_name: user.display_name || user.username || I18n.t("sgu.public_identity.anonymous"),
        username: user.username, public_profile: true, id: user.id }
    else
      { display_name: I18n.t("sgu.public_identity.anonymous"), username: nil, public_profile: false, id: nil }
    end
  end
end
