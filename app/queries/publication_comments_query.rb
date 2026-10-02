# Comentários em ordem cronológica, somente enquanto a publicação estiver acessível.
class PublicationCommentsQuery
  def initialize(viewer, publication)
    @viewer = viewer
    @publication = publication
  end

  def call
    CommentPolicy::Scope.new(@viewer, Comment.all).resolve
      .where(publication_id: @publication.id)
      .chronological
  end
end
