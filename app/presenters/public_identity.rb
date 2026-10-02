# Identifica perfis públicos; contas privadas ou desativadas recebem identidade neutra.
module PublicIdentity
  module_function

  def for(user)
    if user&.active? && user.public_profile?
      { display_name: user.display_name || user.username || I18n.t("sgu.public_identity.anonymous"),
        username: user.username, public_profile: true }
    else
      { display_name: I18n.t("sgu.public_identity.anonymous"), username: nil, public_profile: false }
    end
  end
end
