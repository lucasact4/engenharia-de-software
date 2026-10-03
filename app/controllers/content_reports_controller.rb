# Denúncias da própria pessoa: criar (publicação ou comentário acessível), consultar e reabrir
# com novas informações. Denúncias não aparecem no mural e não ocultam o conteúdo sozinhas.
class ContentReportsController < PortalController
  before_action :set_target, only: %i[new create]

  def index
    authorize :panel, :show?
    @pagy, @reports = pagy(policy_scope(ContentReport).where(reporter_id: Current.user.id)
      .includes(:publication, comment: :publication).order(created_at: :desc), limit: 20)
  end

  def show
    @report = policy_scope(ContentReport).find(params[:id])
    authorize @report, :show?
  end

  def new
    authorize_target
    @report = ContentReport.new
  end

  def create
    authorize_target
    @report = ContentReports::Create.call(actor: Current.user, target: @target, reason: params[:reason], details: params[:details])
    redirect_to publication_path(@target_publication), status: :see_other,
                notice: "Denúncia registrada. Só a administração vê quem denunciou; acompanhe em “Minhas denúncias”."
  rescue ActiveRecord::RecordInvalid => error
    @report = error.record
    render :new, status: :unprocessable_entity
  end

  def reopen
    @report = policy_scope(ContentReport).find(params[:id])
    authorize @report, :reopen?
    ContentReports::Reopen.call(actor: Current.user, report: @report, details: params[:details])
    redirect_to content_report_path(@report), notice: "Denúncia reaberta para nova análise.", status: :see_other
  rescue ActiveRecord::RecordInvalid
    @report.errors.add(:details, :blank) if @report.errors.empty?
    render :show, status: :unprocessable_entity
  end

  private

    def set_target
      if params[:comment_id]
        @target = policy_scope(Comment).find(params[:comment_id])
        @target_publication = @target.publication
      else
        @target = PublicationPolicy::FeedScope.new(Current.user, Publication.all).resolve.find(params[:publication_id])
        @target_publication = @target
      end
    end

    def authorize_target
      @target.is_a?(Comment) ? authorize(@target, :report?) : authorize(@target, :interact?)
    end
end
