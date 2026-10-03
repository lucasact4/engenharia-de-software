# Base do portal (mural público e área autenticada de pessoas usuárias e equipes).
# Cada ação autoriza a query de domínio da policy e consulta registros por scopes autorizados;
# a escrita passa pelos services. Áreas administrativas ficam em Admin::ApplicationController.
class PortalController < ApplicationController
  include Pagy::Method
  include Pundit::Authorization
  include ErrorResponses

  layout "portal"

  # Páginas públicas também reconhecem a sessão, quando houver.
  before_action :resume_session
  after_action :verify_authorized

  def pundit_user
    Current.user
  end

  private

    # Formulários de atendimento e edição usam lock_version; o 409 recarrega o registro e
    # preserva o que a pessoa preencheu para que ela revise antes de reenviar.
    def stale_conflict_message
      "Outra pessoa alterou este registro enquanto você editava. Os dados atuais foram recarregados; " \
        "seu preenchimento foi mantido no formulário. Revise e envie novamente se ainda fizer sentido."
    end
end
