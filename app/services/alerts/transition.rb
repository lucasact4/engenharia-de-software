module Alerts
  # Aplica a matriz de atendimento; reabrir exige motivo e encerramento exige justificativa.
  class Transition < ApplicationService
    class InvalidTransition < StandardError; end

    attr_reader :actor

    def initialize(actor:, alert:, to:, reason: nil, closure_reason: nil, closure_notes: nil,
                   duplicate_of: nil, lock_version: nil)
      @actor = actor
      @alert = alert
      @to = to.to_s
      @reason = reason
      @closure_reason = closure_reason.presence&.to_s
      @closure_notes = closure_notes
      @duplicate_of = duplicate_of
      @lock_version = lock_version
    end

    def call
      authorize!(@alert, :transition?)
      from = @alert.status
      raise InvalidTransition, "#{from} -> #{@to} não é permitido" unless @alert.transition_allowed?(@to)

      reopening = @alert.reopening?(@to)
      if reopening
        authorize!(@alert, :reopen_closed?) if from == "closed"
        require_reason!(@reason, @alert)
      end

      apply_lock_version(@alert, @lock_version)
      now = Time.current
      apply_status_change(from, now)
      changes = @alert.changes.slice(*AuditEvent::ALLOWED_CHANGES["Alert"])

      Alert.transaction do
        @alert.save!
        AuditEvent.record!(
          actor: actor, action: "alert.status_changed", subject: @alert, changes: changes,
          reason: @reason, metadata: { reopening: reopening }
        )
      end
      @alert
    rescue ActiveRecord::RecordInvalid
      # Mantém o objeto em memória na situação original; os erros continuam disponíveis.
      errors = @alert.errors.dup
      @alert.restore_attributes
      @alert.errors.merge!(errors)
      raise
    end

    private

      def apply_status_change(from, now)
        @alert.status = @to
        @alert.status_changed_at = now

        case @to
        when "resolved"
          @alert.resolved_at = now
        when "closed"
          apply_closure(from, now)
        when "in_progress"
          @alert.resolved_at = nil if from == "resolved"
        when "triaging"
          clear_closure if from == "closed"
        end
      end

      def apply_closure(from, now)
        reason = @closure_reason || (from == "resolved" ? "resolved" : nil)
        if reason == "resolved" && from != "resolved"
          @alert.errors.add(:closure_reason, :resolved_requires_resolution)
          raise ActiveRecord::RecordInvalid, @alert
        end
        if reason == "duplicate" && @duplicate_of && !Pundit.policy(actor, @duplicate_of).show?
          @alert.errors.add(:duplicate_of, :blank)
          raise ActiveRecord::RecordInvalid, @alert
        end

        @alert.closure_reason = reason
        @alert.closure_notes = @closure_notes
        @alert.duplicate_of = reason == "duplicate" ? @duplicate_of : nil
        @alert.closed_at = now
      end

      def clear_closure
        @alert.closure_reason = nil
        @alert.closure_notes = nil
        @alert.duplicate_of = nil
        @alert.closed_at = nil
        @alert.resolved_at = nil
      end
  end
end
