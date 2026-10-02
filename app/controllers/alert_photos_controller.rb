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

  private

    def pundit_user
      Current.user
    end

    def not_found
      head :not_found
    end
end
