module Users
  # Desativa a conta e encerra sessões, preservando autoria e histórico.
  class Deactivate < ApplicationService
    class SelfDeactivation < StandardError; end

    attr_reader :actor

    def initialize(actor:, user:, reason: nil)
      @actor = actor
      @user = user
      @reason = reason
    end

    def call
      authorize!(@user, :destroy?)
      raise SelfDeactivation if @user == actor

      User.transaction do
        @user.sessions.destroy_all
        @user.update!(deleted_at: Time.current)
        AuditEvent.record!(actor: actor, action: "user.deactivated", subject: @user,
                           changes: @user.saved_changes.slice("deleted_at"), reason: @reason)
      end
      @user
    end
  end
end
