module Alerts
  # Avalia severidade e prioridade sem substituir o relato do autor.
  class Assess < ApplicationService
    PERMITTED = %i[assessed_severity priority].freeze

    attr_reader :actor

    def initialize(actor:, alert:, attributes:, reason: nil, lock_version: nil)
      @actor = actor
      @alert = alert
      @attributes = attributes.to_h.symbolize_keys.slice(*PERMITTED)
      @reason = reason
      @lock_version = lock_version
    end

    def call
      authorize!(@alert, :assess?)
      apply_lock_version(@alert, @lock_version)
      @alert.assign_attributes(@attributes)
      changes = @alert.changes.slice("assessed_severity", "priority")
      return @alert if changes.empty?

      Alert.transaction do
        @alert.save!
        AuditEvent.record!(actor: actor, action: "alert.assessed", subject: @alert, changes: changes, reason: @reason)
      end
      @alert
    end
  end
end
