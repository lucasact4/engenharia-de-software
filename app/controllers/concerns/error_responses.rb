# Respostas de erro das áreas de domínio (portal e admin):
# 404 para inexistente ou inacessível (sem revelar existência), 403 para ação negada em
# contexto autorizado e 409 para conflito de concorrência ou idempotência.
module ErrorResponses
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from Pundit::NotAuthorizedError, with: :render_forbidden
  end

  private

    def render_not_found
      respond_to do |format|
        format.html { render "errors/not_found", status: :not_found, layout: error_layout }
        format.any { head :not_found }
      end
    end

    def render_forbidden
      respond_to do |format|
        format.html { render "errors/forbidden", status: :forbidden, layout: error_layout }
        format.any { head :forbidden }
      end
    end

    def error_layout
      "portal"
    end
end
