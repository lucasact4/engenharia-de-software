# Fila de revisão e histórico dos cadastros, incluindo os liberados automaticamente.
class Admin::RegistrationsController < Admin::ApplicationController
  include ErrorResponses
  before_action :set_registration, only: %i[show approve reject]

  def index
    authorize User, :index?, policy_class: RegistrationReviewPolicy
    scope = policy_scope(User, policy_scope_class: RegistrationReviewPolicy::Scope)
    scope = scope.where(registration_status: params[:status]) if User.registration_statuses.key?(params[:status].to_s)
    scope = scope.text_search(params[:q], "users.display_name", "users.email_address")
    @pagy, @registrations = pagy(scope.includes(:registration_reviewed_by).order(created_at: :desc, id: :desc), limit: 20)
  end

  def show
    authorize @registration, :show?, policy_class: RegistrationReviewPolicy
  end

  def approve
    review("approve", "Cadastro aprovado. A pessoa já pode entrar.")
  end

  def reject
    review("reject", "Cadastro reprovado. O acesso foi bloqueado e as sessões foram encerradas.")
  end

  private

    def set_registration
      @registration = policy_scope(User, policy_scope_class: RegistrationReviewPolicy::Scope).find(params[:id])
    end

    def review(decision, message)
      authorize @registration, decision == "approve" ? :approve? : :reject?, policy_class: RegistrationReviewPolicy
      Users::ReviewRegistration.call(actor: Current.user, user: @registration, decision: decision, reason: params[:reason])
      redirect_to admin_registration_path(@registration), notice: message, status: :see_other
    rescue ActiveRecord::RecordInvalid
      @reason = params[:reason]
      render :show, status: :unprocessable_content
    end
end
