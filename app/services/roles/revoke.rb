module Roles
  # Revoga um papel (mesmo inativo). Exige administrador ativo e registra auditoria.
  class Revoke < ApplicationService
    attr_reader :actor

    def initialize(actor:, user:, role:, reason: nil)
      @actor = actor
      @user = user
      @role = role
      @reason = reason
    end

    def call
      authorize!(@user, :revoke?, policy_class: RoleAssignmentPolicy)
      user_role = @user.user_roles.find_by(role: @role)
      return if user_role.nil?

      UserRole.transaction do
        user_role.destroy!
        AuditEvent.record!(actor: actor, action: "user.role_revoked", subject: @user, reason: @reason,
                           metadata: { role_code: @role.code })
      end
      nil
    end
  end
end
