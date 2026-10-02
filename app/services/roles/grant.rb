module Roles
  # Concede papel institucional; exige administrador ativo e impede autoconcessão.
  class Grant < ApplicationService
    attr_reader :actor

    def initialize(actor:, user:, role:, reason: nil)
      @actor = actor
      @user = user
      @role = role
      @reason = reason
    end

    def call
      authorize!(@user, :grant?, policy_class: RoleAssignmentPolicy)
      unless @role.active? && Role::RECOGNIZED_CODES.include?(@role.code)
        @user.errors.add(:roles, :unavailable)
        raise ActiveRecord::RecordInvalid, @user
      end

      existing = @user.user_roles.find_by(role: @role)
      return existing if existing

      UserRole.transaction do
        user_role = @user.user_roles.create!(role: @role, granted_by: actor)
        AuditEvent.record!(actor: actor, action: "user.role_granted", subject: @user, reason: @reason,
                           metadata: { role_code: @role.code })
        user_role
      end
    end
  end
end
