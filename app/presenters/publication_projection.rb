# Expõe apenas conteúdo editorial autorizado, sem dados operacionais do alerta.
class PublicationProjection
  def initialize(publication, viewer: nil)
    @publication = publication
    @viewer = viewer
  end

  def as_json(*)
    @publication.reload
    Pundit.authorize(@viewer, @publication, :show?)

    {
      id: @publication.id,
      kind: @publication.kind,
      kind_label: I18n.t("enums.publication.kind.#{@publication.kind}.label"),
      title: @publication.title,
      body: @publication.body,
      visibility: @publication.visibility,
      published_at: @publication.published_at&.iso8601,
      expires_at: @publication.expires_at&.iso8601,
      comments_enabled: @publication.comments_enabled,
      editorial_identity: I18n.t("sgu.public_identity.editorial"),
      likes_count: @publication.publication_likes.where(user_id: User.active.select(:id)).count,
      comments_count: @publication.comments.visible_content.count,
      viewer_state: viewer_state
    }
  end

  private

    # Estado privado somente da própria pessoa que está lendo.
    def viewer_state
      return nil unless @viewer&.active?

      {
        liked: @publication.publication_likes.exists?(user_id: @viewer.id),
        bookmarked: @publication.publication_bookmarks.exists?(user_id: @viewer.id),
        subscribed: @publication.publication_subscriptions.exists?(user_id: @viewer.id)
      }
    end
end
