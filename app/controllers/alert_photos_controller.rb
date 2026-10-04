# Entrega e remove fotos privadas após conferir o acesso ao alerta e ao anexo.
# Inexistente ou inacessível sempre responde 404, sem revelar se o arquivo existe.
class AlertPhotosController < ApplicationController
  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError, ActiveRecord::RecordNotFound, with: :not_found

  def show
    alert = policy_scope(Alert).find(params[:alert_id])
    authorize alert, :show_photos?
    blob = alert.photos_attachments.find(params[:id]).blob

    response.headers["Cache-Control"] = "private, no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Content-Security-Policy"] = "default-src 'none'; sandbox"
    send_data blob.download, type: blob.content_type, disposition: "inline", filename: blob.filename.sanitized
  end

  def destroy
    alert = policy_scope(Alert).find(params[:alert_id])
    authorize alert, :remove_photo?
    Alerts::RemovePhoto.call(actor: Current.user, alert: alert, attachment_id: params[:id],
                             reason: params[:reason], lock_version: params[:lock_version])
    redirect_to return_path(alert), notice: "Foto removida do registro.", status: :see_other
  rescue ActiveRecord::RecordInvalid
    redirect_to return_path(alert), alert: "Informe o motivo da remoção.", status: :see_other
  rescue ActiveRecord::StaleObjectError
    redirect_to return_path(alert), alert: "O registro mudou enquanto você revisava. Confira as fotos e tente de novo.", status: :see_other
  end

  private

    def pundit_user
      Current.user
    end

    def return_path(alert)
      Authentication.safe_return_path(params[:return_to]) || alert_path(alert)
    end

    def not_found
      head :not_found
    end
end
