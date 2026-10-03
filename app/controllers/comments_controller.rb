# Comentários de publicações: raiz ou resposta direta (um nível). Acesso, conta ativa e
# comentários habilitados são revalidados no envio pelo service, mesmo com a página aberta
# antes de uma retirada. Apagar é lógico e preserva as respostas de outras pessoas.
class CommentsController < PortalController
  allow_unauthenticated_access only: :show

  before_action :set_comment, only: %i[show edit update destroy]

  # Conversa completa de um comentário raiz (respostas paginadas).
  def show
    authorize @comment, :show?
    @root = @comment.root? ? @comment : @comment.parent
    publication = @root.publication
    @permissions = PublicationPermissions.new(Current.user, publication)
    @pagy, replies = pagy(@root.replies.chronological, limit: 30)
    projections = CommentProjection.collection([ @root ] + replies.to_a, viewer: Current.user)
    @root_projection = projections.first
    @replies = projections.drop(1)
    @publication = publication
  end

  def create
    @publication = PublicationPolicy::FeedScope.new(Current.user, Publication.all).resolve.find(params[:publication_id])
    authorize @publication, :comment?
    parent = find_parent
    comment = Comments::Create.call(actor: Current.user, publication: @publication, body: params[:body], parent: parent)
    redirect_to publication_path(@publication, anchor: "comment_#{comment.id}"), notice: "Comentário publicado.", status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    @errors = error.record.errors.full_messages
    @parent_id = params[:parent_id].presence
    render :new, status: :unprocessable_entity
  end

  def edit
    authorize @comment, :update?
  end

  def update
    authorize @comment, :update?
    Comments::Update.call(actor: Current.user, comment: @comment, body: params[:body], lock_version: params[:lock_version])
    redirect_to publication_path(@comment.publication_id, anchor: "comment_#{@comment.id}"), notice: "Comentário atualizado.", status: :see_other
  rescue ActiveRecord::RecordInvalid
    @body = params[:body]
    render :edit, status: :unprocessable_entity
  rescue ActiveRecord::StaleObjectError
    @body = params[:body]
    @comment.reload
    flash.now[:alert] = "Este comentário mudou em outra aba ou dispositivo. Seu texto foi mantido; revise e salve de novo."
    render :edit, status: :conflict
  end

  def destroy
    authorize @comment, :destroy?
    Comments::Delete.call(actor: Current.user, comment: @comment)
    redirect_to publication_path(@comment.publication_id, anchor: "comment_#{@comment.id}"), notice: "Comentário apagado.", status: :see_other
  end

  private

    def set_comment
      @comment = policy_scope(Comment).find(params[:id])
    end

    # Pai buscado no scope de leitura; de outra publicação, resposta ou oculto é rejeitado
    # pelo model/service (nunca vira um comentário raiz por engano).
    def find_parent
      return nil if params[:parent_id].blank?

      parent = policy_scope(Comment).find_by(id: params[:parent_id])
      return parent if parent

      comment = Comment.new(publication: @publication)
      comment.errors.add(:parent, :blank)
      raise ActiveRecord::RecordInvalid, comment
    end
end
