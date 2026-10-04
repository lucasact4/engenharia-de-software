# Avatar público apenas com opt-in; o proprietário acessa a própria foto privada.
class ProfilePhotosController < PortalController
  allow_unauthenticated_access only: :show
  rescue_from ActiveRecord::RecordNotFound, Pundit::NotAuthorizedError, Vips::Error, ActiveStorage::FileNotFoundError, ActiveStorage::IntegrityError, with: :not_found

  def show
    person = User.active.find(params[:id])
    if Current.user&.id == person.id
      authorize person, :show?, policy_class: ProfilePolicy
    else
      authorize person, :show?, policy_class: PublicProfilePolicy
    end
    raise ActiveRecord::RecordNotFound unless person.avatar.attached?

    photo = person.avatar.variant(resize_to_fill: [ 160, 160 ], format: :jpeg, saver: { strip: true, quality: 85 }).processed
    response.headers["Cache-Control"] = "private, no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    send_data photo.download, type: "image/jpeg", disposition: "inline", filename: "perfil.jpg"
  end

  private

    def not_found
      skip_authorization
      head :not_found
    end
end
