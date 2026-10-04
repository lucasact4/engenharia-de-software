# Exibe comentários; os removidos mantêm o lugar na conversa, sem texto nem autoria.
class CommentProjection
  # Listagens: autoriza pelo scope atual, carrega autores e curtidas em lote e devolve o mesmo
  # formato de as_json. Comentário oculto nunca leva corpo, autoria ou curtidas no payload.
  def self.collection(comments, viewer: nil)
    records = comments.to_a
    return [] if records.empty?

    allowed = CommentPolicy::Scope.new(viewer, Comment.where(id: records.map(&:id))).resolve.pluck(:id).to_set
    records = records.select { |comment| allowed.include?(comment.id) }
    visible_ids = records.reject(&:hidden?).map(&:id)
    likes = CommentLike.where(comment_id: visible_ids, user_id: User.active.select(:id)).group(:comment_id).count
    liked = viewer&.active? ? CommentLike.where(user_id: viewer.id, comment_id: visible_ids).pluck(:comment_id).to_set : Set.new
    authors = User.where(id: records.reject(&:hidden?).map(&:author_id)).index_by(&:id)

    records.map do |comment|
      new(comment, viewer: viewer).payload(
        author: comment.hidden? ? nil : PublicIdentity.for(authors[comment.author_id]),
        likes_count: comment.hidden? ? 0 : likes.fetch(comment.id, 0)
      ).merge(viewer_liked: liked.include?(comment.id), own: viewer.present? && comment.author_id == viewer.id)
    end
  end

  def initialize(comment, viewer: nil)
    @comment = comment
    @viewer = viewer
  end

  def as_json(*)
    @comment.reload
    Pundit.authorize(@viewer, @comment, :show?)

    payload(
      author: @comment.hidden? ? nil : PublicIdentity.for(@comment.author),
      likes_count: @comment.hidden? ? 0 : @comment.comment_likes.where(user_id: User.active.select(:id)).count
    )
  end

  def payload(author:, likes_count:)
    {
      id: @comment.id,
      parent_id: @comment.parent_id,
      state: state,
      body: @comment.hidden? ? nil : @comment.body,
      author: author,
      edited: @comment.edited_at.present?,
      created_at: @comment.created_at.iso8601,
      likes_count: likes_count
    }
  end

  private

    def state
      return "removed" if @comment.removed?
      return "deleted" if @comment.deleted?

      "visible"
    end
end
