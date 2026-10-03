# Mural: somente publicações no ar para quem lê (PublicationPolicy::FeedScope). Anônimos veem
# apenas conteúdo externo; contas ativas veem também o interno. Rascunhos ficam no admin.
# Cartões e detalhes usam PublicationProjection/CommentProjection: sem dados operacionais do alerta.
class PublicationsController < PortalController
  ROOTS_PER_PAGE = 20
  REPLIES_PREVIEW = 5

  allow_unauthenticated_access only: %i[index show]

  def index
    authorize Publication, :index?
    scope = feed_scope
    scope = scope.where(kind: params[:kind]) if Publication.kinds.key?(params[:kind].to_s)
    scope = scope.where(visibility: params[:audience]) if Current.user && Publication.visibilities.key?(params[:audience].to_s)
    scope = scope.text_search(params[:q], "publications.title", "publications.body")
    @pagy, records = pagy(scope.order(published_at: :desc, id: :desc), limit: 10)
    @cards = PublicationProjection.collection(records, viewer: Current.user)
  end

  def show
    @publication = feed_scope.find(params[:id])
    authorize @publication, :show?
    @card = PublicationProjection.collection([ @publication ], viewer: Current.user).first
    @permissions = PublicationPermissions.new(Current.user, @publication)
    load_comments
  end

  private

    def feed_scope
      PublicationPolicy::FeedScope.new(Current.user, Publication.all).resolve
    end

    # Raízes paginadas; de cada raiz, só as primeiras respostas (o restante abre na página do comentário).
    def load_comments
      roots = PublicationCommentsQuery.new(Current.user, @publication).call.roots
      @comments_pagy, root_records = pagy(roots, limit: ROOTS_PER_PAGE, page_key: "comentarios")
      root_ids = root_records.map(&:id)
      ranked = Comment.where(parent_id: root_ids)
        .select("comments.*, ROW_NUMBER() OVER (PARTITION BY comments.parent_id ORDER BY comments.created_at, comments.id) AS reply_rank")
      replies = Comment.from(ranked, :comments).where("reply_rank <= ?", REPLIES_PREVIEW).order(:created_at, :id).to_a
      @reply_counts = Comment.where(parent_id: root_ids).group(:parent_id).count
      projections = CommentProjection.collection(root_records + replies, viewer: Current.user).index_by { |c| c[:id] }
      @comment_roots = root_ids.filter_map { |id| projections[id] }
      @comment_replies = replies.filter_map { |reply| projections[reply.id] }.group_by { |c| c[:parent_id] }
    end
end
