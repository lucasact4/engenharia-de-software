module Users
  # Reprovar bloqueia acessos e encerra sessões; a autoria e o histórico permanecem intactos.
  class ReviewRegistration < ApplicationService
    attr_reader :actor

    def initialize(actor:, user:, decision:, reason: nil)
      @actor = actor
      @user = user
      @decision = decision.to_s
      @reason = reason.to_s.strip
    end

    def call
      query = { "approve" => :approve?, "reject" => :reject? }.fetch(@decision) { raise ArgumentError, "decisão inválida" }
      authorize!(@user, query, policy_class: RegistrationReviewPolicy)
      require_reason!(@reason, @user) if @decision == "reject"
      User.transaction do
        @user.lock!
        authorize!(@user, query, policy_class: RegistrationReviewPolicy)
        @user.assign_attributes(registration_status: @decision == "approve" ? "approved" : "rejected",
                                registration_reviewed_by: actor, registration_reviewed_at: Time.current,
                                registration_review_reason: @reason.presence)
        @user.save!
        @user.sessions.destroy_all if @user.registration_rejected?
        AuditEvent.record!(actor: actor, action: "user.registration_reviewed", subject: @user,
                           changes: @user.saved_changes, reason: @reason, metadata: { decision: @decision })
      end
      @user
    end
  end
end
