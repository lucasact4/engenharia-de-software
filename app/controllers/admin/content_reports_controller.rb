# frozen_string_literal: true

# Análise de denúncias. Decidir a denúncia (procedente/improcedente) não remove conteúdo:
# a moderação é uma ação separada e explícita (remover comentário ou retirar publicação).
class Admin::ContentReportsController < Admin::ApplicationController
  include ErrorResponses

  before_action :set_report, except: :index

  def index
    authorize ContentReport, :index?
    scope = policy_scope(ContentReport)
    state = params.fetch(:state, "pending")
    scope = scope.where(state: state) if ContentReport.states.key?(state)
    scope = scope.where(reason: params[:reason]) if ContentReport.reasons.key?(params[:reason].to_s)
    scope = scope.where.not(comment_id: nil) if params[:target] == "comment"
    scope = scope.where.not(publication_id: nil) if params[:target] == "publication"
    @state = state
    @pagy, @reports = pagy(scope.includes(:publication, comment: :publication).order(created_at: :desc, id: :desc), limit: 20)
  end

  def show
    authorize @report, :show?
    prepare_show
  end

  def review
    authorize @report, :review?
    ContentReports::Review.call(actor: Current.user, report: @report, decision: params[:decision], notes: params[:notes])
    redirect_to admin_content_report_path(@report), flash: { success: "Decisão registrada. O conteúdo só muda se você usar uma ação de moderação." }, status: :see_other
  rescue ArgumentError, ActiveRecord::RecordInvalid
    @report.errors.add(:base, "Escolha “Procedente” ou “Improcedente”.")
    prepare_show
    render :show, status: :unprocessable_entity
  end

  private

    def set_report
      @report = policy_scope(ContentReport).find(params[:id])
    end

    def prepare_show
      @target_publication = @report.target_publication
      @events = AuditEvent.for_subject(@report).includes(:actor).order(:created_at, :id)
    end

    def error_layout
      "admin/base"
    end
end
