module Comments
  # Moderação com motivo e auditoria; preserva o texto para análise administrativa.
  class Moderate < ApplicationService
    attr_reader :actor

    def initialize(actor:, comment:, reason:)
      @actor = actor
      @comment = comment
      @reason = reason
    end

    def call
      authorize!(@comment, :moderate?)
      require_reason!(@reason, @comment)
      return @comment if @comment.removed?

      @comment.assign_attributes(removed_at: Time.current, removed_by: actor, removal_reason: @reason)
      changes = @comment.changes
      Comment.transaction do
        @comment.save!
        AuditEvent.record!(actor: actor, action: "comment.removed", subject: @comment, changes: changes, reason: @reason)
      end
      @comment
    end
  end
end
