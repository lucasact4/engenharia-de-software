# Exibe comentários; os removidos mantêm o lugar na conversa, sem texto nem autoria.
class CommentProjection
  def initialize(comment, viewer: nil)
    @comment = comment
    @viewer = viewer
  end

  def as_json(*)
    @comment.reload
    Pundit.authorize(@viewer, @comment, :show?)

    {
      id: @comment.id,
      parent_id: @comment.parent_id,
      state: state,
      body: @comment.hidden? ? nil : @comment.body,
      author: @comment.hidden? ? nil : PublicIdentity.for(@comment.author),
      edited: @comment.edited_at.present?,
      created_at: @comment.created_at.iso8601,
      likes_count: @comment.hidden? ? 0 : @comment.comment_likes.where(user_id: User.active.select(:id)).count
    }
  end

  private

    def state
      return "removed" if @comment.removed?
      return "deleted" if @comment.deleted?

      "visible"
    end
end
