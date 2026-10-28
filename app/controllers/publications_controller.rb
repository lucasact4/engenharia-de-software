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
    @categories = Category.active.ordered
    scope = filter_feed(scope)
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

    def filter_feed(scope)
      scope = scope.left_joins(:alert, :author).left_joins(alert: :category)

      keyword = params[:q].to_s.strip
      if keyword.present?
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(keyword.downcase)}%"
        id = keyword.match?(/\A\d+\z/) ? keyword.to_i : -1
        scope = scope.where(
          "LOWER(COALESCE(alerts.title, publications.title, '')) LIKE :term OR " \
          "LOWER(COALESCE(alerts.description, publications.body, '')) LIKE :term OR " \
          "LOWER(COALESCE(categories.name, '')) LIKE :term OR " \
          "alerts.protocol = :protocol OR publications.id = :id",
          term: pattern, protocol: keyword, id: id
        )
      end

      creator = params[:creator].to_s.strip
      if creator.present?
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(creator.downcase)}%"
        scope = scope.where(
          "LOWER(COALESCE(users.display_name, '')) LIKE :creator OR " \
          "LOWER(COALESCE(users.business_name, '')) LIKE :creator OR " \
          "LOWER(COALESCE(users.username, '')) LIKE :creator",
          creator: pattern
        )
      end

      category_id = params[:category_id].to_s
      scope = scope.where(alerts: { category_id: category_id }) if category_id.match?(/\A\d+\z/) && Category.exists?(id: category_id)

      severity = params[:severity].to_s
      if Alert.reported_severities.key?(severity)
        scope = scope.where("alerts.reported_severity = :severity OR alerts.assessed_severity = :severity", severity: severity)
      end

      scope.distinct
    end

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
