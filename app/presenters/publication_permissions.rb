# O que a pessoa pode fazer numa publicação agora, calculado uma vez por página a partir da
# PublicationPolicy. Serve só para exibir botões: os services revalidam cada envio.
class PublicationPermissions
  def initialize(viewer, publication)
    @viewer = viewer
    @policy = PublicationPolicy.new(viewer, publication)
  end

  def signed_in?
    @viewer&.active?
  end

  def interact?
    @interact = @policy.interact? if @interact.nil?
    @interact
  end

  def comment?
    @comment = @policy.comment? if @comment.nil?
    @comment
  end

  def moderate?
    signed_in? && @viewer.admin?
  end

  # Para um comentário projetado (hash de CommentProjection): mesmas regras da CommentPolicy.
  def edit_comment?(comment)
    interact? && comment[:own] && comment[:state] == "visible"
  end

  def like_comment?(comment)
    interact? && comment[:state] == "visible"
  end

  def report_comment?(comment)
    like_comment?(comment) && !comment[:own]
  end

  def reply_to?(comment)
    comment? && comment[:parent_id].nil? && comment[:state] == "visible"
  end
end
