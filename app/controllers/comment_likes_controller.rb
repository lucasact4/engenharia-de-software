# Curtir/descurtir comentário (POST/DELETE idempotentes). Exige acesso atual à publicação e
# comentário visível; descurtir remove só o vínculo próprio.
class CommentLikesController < PortalController
  def create
    comment = policy_scope(Comment).find(params[:comment_id])
    authorize comment, :like?
    Social::Interactions.like_comment(actor: Current.user, comment: comment)
    redirect_to publication_path(comment.publication_id, anchor: "comment_#{comment.id}"), status: :see_other
  end

  def destroy
    skip_authorization # só apaga a curtida da própria sessão
    Social::Interactions.unlike_comment(actor: Current.user, comment: Comment.new(id: params[:comment_id].to_i))
    comment = policy_scope(Comment).find_by(id: params[:comment_id])
    redirect_to (comment ? publication_path(comment.publication_id, anchor: "comment_#{comment.id}") : publications_path), status: :see_other
  end
end
