module Alerts
  # Atribui atendimento a uma conta ativa habilitada para o tipo de alerta.
  class Assign < ApplicationService
    attr_reader :actor

    def initialize(actor:, alert:, assignee:, reason: nil, lock_version: nil)
      @actor = actor
      @alert = alert
      @assignee = assignee
      @reason = reason
      @lock_version = lock_version
    end

    def call
      authorize!(@alert, :assign?)
      ensure_eligible!
      apply_lock_version(@alert, @lock_version)
      @alert.assigned_to = @assignee
      changes = @alert.changes.slice("assigned_to_id")
      return @alert if changes.empty?

      Alert.transaction do
        @alert.save!
        AuditEvent.record!(actor: actor, action: "alert.assigned", subject: @alert, changes: changes, reason: @reason)
      end
      @alert
    end

    private

      def ensure_eligible!
        return if @assignee.nil?
        return if @assignee.active? && (@assignee.admin? || eligible_role?)

        @alert.errors.add(:assigned_to, :not_eligible)
        raise ActiveRecord::RecordInvalid, @alert
      end

      def eligible_role?
        return @assignee.role?(:security) if @alert.panic?

        @assignee.role?(:coordination) || @assignee.role?(:security)
      end
  end
end
