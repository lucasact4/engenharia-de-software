# frozen_string_literal: true

# Ciclo editorial: rascunho → revisão (aprovar/rejeitar a versão lida) → publicação → retirada.
# Aprovado não significa publicado. Mudança relevante invalida a aprovação (Publications::Update).
# Não há exclusão: publicações saem do ar por retirada com motivo, preservando comentários e denúncias.
class Admin::PublicationsController < Admin::ApplicationController
  include ErrorResponses

  STATES = %w[draft published withdrawn].freeze
  FIELDS = %i[title body visibility expires_at comments_enabled].freeze

  before_action :set_publication, except: %i[index new create]

  def index
    authorize Publication, :manage?
    scope = policy_scope(Publication)
    scope = scope.where(state: params[:state]) if STATES.include?(params[:state])
    scope = scope.where(review_status: params[:review]) if Publication.review_statuses.key?(params[:review].to_s)
    scope = scope.where(kind: params[:kind]) if Publication.kinds.key?(params[:kind].to_s)
    scope = scope.where(visibility: params[:visibility]) if Publication.visibilities.key?(params[:visibility].to_s)
    scope = scope.needing_source_review if params[:source_review] == "1"
    scope = scope.text_search(params[:q], "publications.title")
    @pagy, @publications = pagy(scope.includes(:alert).order(updated_at: :desc, id: :desc), limit: 20)
  end

  def show
    authorize @publication, :manage?
    prepare_show
  end

  def new
    authorize Publication, :create?
    @source = source_from_params
    @publication = Publication.new(kind: @source ? "occurrence" : "news", visibility: default_visibility(@source), comments_enabled: true)
    prepare_form
  end

  def create
    authorize Publication, :create?
    @source = source_from_params
    @publication = Publications::Create.call(actor: Current.user, attributes: publication_params.merge(kind: params.dig(:publication, :kind)),
                                             alert: @source)
    redirect_to admin_publication_path(@publication), flash: { success: "Rascunho criado. Envie para revisão quando estiver pronto." }, status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    @publication = error.record.is_a?(Publication) ? error.record : Publication.new(publication_params)
    prepare_form
    render :new, status: :unprocessable_entity
  end

  def edit
    authorize @publication, :update?
    prepare_form
  end

  def update
    authorize @publication, :update?
    Publications::Update.call(actor: Current.user, publication: @publication, attributes: publication_params,
                              lock_version: params[:lock_version])
    redirect_to admin_publication_path(@publication), flash: { success: update_message }, status: :see_other
  rescue ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError => error
    errors = @publication.errors.dup
    @publication = Publication.find(@publication.id)
    @publication.assign_attributes(publication_params)
    errors.each { |item| @publication.errors.import(item) }
    flash.now[:alert] = stale_message if error.is_a?(ActiveRecord::StaleObjectError)
    prepare_form
    render :edit, status: (error.is_a?(ActiveRecord::StaleObjectError) ? :conflict : :unprocessable_entity)
  end

  def submit_review
    authorize @publication, :submit?
    editorial_action("Enviada para revisão.") { Publications::Submit.call(actor: Current.user, publication: @publication) }
  end

  # A decisão vale para a versão de conteúdo exibida ao revisor (reviewed_content_version).
  def review
    authorize @publication, :review?
    message = params[:decision] == "approve" ? "Versão aprovada. Ela ainda não está no ar: publique quando quiser." : "Revisão rejeitada com justificativa."
    editorial_action(message) do
      Publications::Review.call(actor: Current.user, publication: @publication, decision: params[:decision],
                                reviewed_content_version: params[:reviewed_content_version], reason: params[:reason],
                                lock_version: params[:lock_version])
    end
  end

  def publish
    authorize @publication, :publish?
    editorial_action("Publicação no ar para a audiência definida.") do
      Publications::Publish.call(actor: Current.user, publication: @publication, lock_version: params[:lock_version])
    end
  end

  # Retirada preserva histórico, comentários e denúncias; novas interações deixam de ser aceitas.
  def withdraw
    authorize @publication, :withdraw?
    editorial_action("Publicação retirada do ar.") do
      Publications::Withdraw.call(actor: Current.user, publication: @publication, reason: params[:reason])
    end
  end

  private

    def set_publication
      @publication = policy_scope(Publication).find(params[:id])
    end

    def editorial_action(message)
      yield
      redirect_to return_path, flash: { success: message }, status: :see_other
    rescue ActiveRecord::RecordInvalid, ArgumentError
      errors = @publication.errors.dup
      @publication = Publication.find(@publication.id)
      errors.each { |item| @publication.errors.import(item) }
      @publication.errors.add(:base, "Escolha uma decisão válida.") if errors.empty?
      prepare_show
      render :show, status: :unprocessable_entity
    rescue ActiveRecord::StaleObjectError, Publications::Review::StaleReview
      @publication = Publication.find(@publication.id)
      flash.now[:alert] = stale_message
      prepare_show
      render :show, status: :conflict
    end

    def return_path
      Authentication.safe_return_path(params[:return_to]) || admin_publication_path(@publication)
    end

    def prepare_show
      @events = AuditEvent.for_subject(@publication).includes(:actor).order(:created_at, :id)
      @stats = {
        likes: @publication.publication_likes.where(user_id: User.active.select(:id)).count,
        comments: @publication.comments.visible_content.count,
        hidden_comments: @publication.comments.where.not(removed_at: nil).or(@publication.comments.where.not(deleted_at: nil)).count,
        pending_reports: ContentReport.pending.where(publication_id: @publication.id)
          .or(ContentReport.pending.where(comment_id: @publication.comments.select(:id))).count
      }
      @pagy, @comments = pagy(@publication.comments.includes(:author).order(created_at: :desc, id: :desc), limit: 20)
      @feed_visible = PublicationPolicy::FeedScope.new(nil, Publication.where(id: @publication.id)).resolve.exists? ||
        PublicationPolicy::FeedScope.new(Current.user, Publication.where(id: @publication.id)).resolve.exists?
    end

    def prepare_form
      @sources = PublicationSourcesQuery.new(Current.user, term: params[:source_q]).call if @publication.new_record?
    end

    def source_from_params
      alert_id = params[:alert_id].presence || params.dig(:publication, :alert_id).presence
      return if alert_id.nil?

      policy_scope(Alert).find(alert_id)
    end

    def default_visibility(source)
      source&.requested_internal? ? "internal" : "public_external"
    end

    def publication_params
      params.fetch(:publication, {}).permit(*FIELDS).to_h.symbolize_keys.tap do |attributes|
        attributes[:expires_at] = attributes[:expires_at].presence if attributes.key?(:expires_at)
      end
    end

    def update_message
      @publication.published? ? "Publicação atualizada." : "Alterações salvas. Mudanças relevantes exigem nova revisão antes de voltar ao ar."
    end

    def stale_message
      "A publicação mudou enquanto você a revisava (outra edição, revisão ou publicação). Os dados atuais foram recarregados; confira antes de repetir a ação."
    end

    def error_layout
      "admin/base"
    end
end
