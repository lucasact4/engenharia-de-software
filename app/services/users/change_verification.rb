module Users
  class ChangeVerification < ApplicationService
    attr_reader :actor

    def initialize(actor:, user:, verified:)
      @actor, @user, @verified = actor, user, verified
    end

    def call
      authorize!(@user, :update?, policy_class: UserVerificationPolicy)
      User.transaction do
        @user.lock!
        authorize!(@user, :update?, policy_class: UserVerificationPolicy)
        @user.assign_attributes(verified_at: @verified ? Time.current : nil, verified_by: @verified ? actor : nil)
        changes = @user.changes
        @user.save!
        AuditEvent.record!(actor: actor, action: @verified ? "user.verification_granted" : "user.verification_revoked",
                           subject: @user, changes: changes)
      end
      @user
    end
  end
end
