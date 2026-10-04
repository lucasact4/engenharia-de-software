# frozen_string_literal: true

# Contas: e-mail e senha pelo CRUD; perfil por Users::UpdateProfile (auditado, sem ativar
# opt-in público em nome da pessoa); papéis por Admin::UserRolesController; desativação por
# Users::Deactivate. O privilégio users.admin não é editável por estas telas.
class Admin::UsersController < Admin::BaseController
  PROFILE_FIELDS = %i[display_name username bio public_profile].freeze

  def show
    @role_options = RoleOptionsPresenter.new(actor: Current.user, user: @instance).options
  end

  def update
    User.transaction do
      @instance.assign_attributes(instance_params)
      @instance.save!(context: @instance.password.present? ? :password_change : nil)
      Users::UpdateProfile.call(actor: Current.user, user: @instance, attributes: profile_params, reason: params[:profile_reason]) if profile_params.any?
    end

    respond_to do |format|
      format.html { redirect_to admin_user_path(@instance), flash: { success: translate_flash("success") } }
      format.json { render :show, status: :ok, location: @instance }
    end
  rescue ActiveRecord::RecordInvalid
    respond_to do |format|
      format.html { render :edit, status: :unprocessable_entity }
      format.json { render json: @instance.errors, status: :unprocessable_entity }
    end
  end

  def destroy
    if @instance == Current.user
      return prevent_self_deactivation
    end

    Users::Deactivate.call(actor: Current.user, user: @instance)

    respond_to do |format|
      format.html { redirect_to send(redirect_to_index), flash: { success: translate_flash("success") } }
      format.json { head :no_content }
    end
  end

  def verification
    user = policy_scope(User).find(params[:id])
    authorize user, :update?, policy_class: UserVerificationPolicy
    Users::ChangeVerification.call(actor: Current.user, user: user, verified: params[:verified] == "1")
    redirect_to admin_user_path(user), notice: user.verified? ? "Selo de verificado concedido." : "Selo de verificado removido.", status: :see_other
  end

  private

  def default_params_permited
    [ :email_address, :password, :password_confirmation ]
  end

  def profile_params
    params.fetch(:user, {}).permit(*PROFILE_FIELDS).to_h.symbolize_keys
  end

  def filter_fields
    [ "users.email_address", "users.display_name", "users.username" ]
  end

  def sort_fields
    [ "users.email_address" ]
  end

  def instance_params
    safe_params = super

    return safe_params.except(:password, :password_confirmation) if safe_params[:password].blank?

    safe_params
  end

  def prevent_self_deactivation
    respond_to do |format|
      format.html do
        redirect_to send(redirect_to_index), alert: t("authentication.users.cannot_deactivate_self")
      end
      format.json do
        render json: { error: t("authentication.users.cannot_deactivate_self") }, status: :unprocessable_entity
      end
    end
  end
end
