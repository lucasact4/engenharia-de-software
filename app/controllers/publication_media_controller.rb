# Acesso revalidado a cada leitura; apenas a versão sem metadados chega ao feed.
class PublicationMediaController < PortalController
  allow_unauthenticated_access only: :show
  rescue_from ActiveRecord::RecordNotFound, Pundit::NotAuthorizedError, Vips::Error, ActiveStorage::FileNotFoundError, ActiveStorage::IntegrityError, with: :not_found

  def show
    publication = policy_scope(Publication).find(params[:publication_id])
    authorize publication, Current.user&.admin? ? :manage? : :show?
    blob = publication.feed_photos.attachments.find(params[:id]).blob
    variant = blob.variant(resize_to_limit: [ 1440, 1440 ], format: :jpeg, saver: { strip: true, quality: 85 }).processed
    response.headers["Cache-Control"] = "private, no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    send_data variant.download, type: "image/jpeg", disposition: "inline", filename: "publicacao-#{publication.id}.jpg"
  end

  private
    def not_found
      skip_authorization
      head :not_found
    end
end
