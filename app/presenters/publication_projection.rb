# Expõe apenas conteúdo editorial autorizado, sem dados operacionais do alerta.
class PublicationProjection
  # Listagens: autoriza todas de uma vez pelo scope e agrega contagens/estado em poucas consultas,
  # mantendo o mesmo formato de as_json. Registros fora do scope atual são descartados.
  def self.collection(publications, viewer: nil)
    records = publications.to_a
    return [] if records.empty?

    allowed = PublicationPolicy::Scope.new(viewer, Publication.where(id: records.map(&:id))).resolve.pluck(:id).to_set
    records = records.select { |publication| allowed.include?(publication.id) }
    ids = records.map(&:id)
    likes = PublicationLike.where(publication_id: ids, user_id: User.active.select(:id)).group(:publication_id).count
    comments = Comment.visible_content.where(publication_id: ids).group(:publication_id).count
    states = viewer_states(viewer, ids)

    records.map do |publication|
      new(publication, viewer: viewer).payload(
        likes_count: likes.fetch(publication.id, 0),
        comments_count: comments.fetch(publication.id, 0),
        viewer_state: states&.transform_values { |set| set.include?(publication.id) }
      )
    end
  end

  def self.viewer_states(viewer, ids)
    return nil unless viewer&.active?

    {
      liked: PublicationLike.where(user_id: viewer.id, publication_id: ids).pluck(:publication_id).to_set,
      bookmarked: PublicationBookmark.where(user_id: viewer.id, publication_id: ids).pluck(:publication_id).to_set,
      subscribed: PublicationSubscription.where(user_id: viewer.id, publication_id: ids).pluck(:publication_id).to_set
    }
  end
  private_class_method :viewer_states

  def initialize(publication, viewer: nil)
    @publication = publication
    @viewer = viewer
  end

  def as_json(*)
    @publication.reload
    Pundit.authorize(@viewer, @publication, :show?)

    payload(
      likes_count: @publication.publication_likes.where(user_id: User.active.select(:id)).count,
      comments_count: @publication.comments.visible_content.count,
      viewer_state: viewer_state
    )
  end

  def payload(likes_count:, comments_count:, viewer_state:)
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
      likes_count: likes_count,
      comments_count: comments_count,
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
