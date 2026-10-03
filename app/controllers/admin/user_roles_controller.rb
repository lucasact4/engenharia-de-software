# frozen_string_literal: true

# Concessão e revogação de papéis institucionais reconhecidos (Roles::Grant/Revoke), com
# auditoria. Não cria papéis nem concede administração; ninguém altera os próprios papéis.
class Admin::UserRolesController < Admin::ApplicationController
  include ErrorResponses

  before_action :set_user

  def create
    authorize @user, :grant?, policy_class: RoleAssignmentPolicy
    role = Role.where(code: Role::RECOGNIZED_CODES).find_by!(code: params[:code])
    Roles::Grant.call(actor: Current.user, user: @user, role: role, reason: params[:reason])
    redirect_to admin_user_path(@user), flash: { success: "Papel “#{role.name}” concedido." }, status: :see_other
  rescue ActiveRecord::RecordInvalid
    redirect_to admin_user_path(@user), alert: "Este papel não está disponível para concessão.", status: :see_other
  end

  def destroy
    authorize @user, :revoke?, policy_class: RoleAssignmentPolicy
    role = Role.find_by!(code: params[:code])
    Roles::Revoke.call(actor: Current.user, user: @user, role: role, reason: params[:reason])
    redirect_to admin_user_path(@user), flash: { success: "Papel “#{role.name}” revogado." }, status: :see_other
  end

  private

    def set_user
      @user = policy_scope(User).find(params[:user_id])
    end

    def error_layout
      "admin/base"
    end
end
