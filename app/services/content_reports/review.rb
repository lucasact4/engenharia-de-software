module ContentReports
  # Registra a decisão da denúncia; a moderação do conteúdo usa seu serviço próprio.
  class Review < ApplicationService
    DECISIONS = %w[actioned dismissed].freeze

    attr_reader :actor

    def initialize(actor:, report:, decision:, notes: nil)
      @actor = actor
      @report = report
      @decision = decision.to_s
      @notes = notes
    end

    def call
      authorize!(@report, :review?)
      raise ArgumentError, "decisão inválida: #{@decision}" unless DECISIONS.include?(@decision)

      @report.assign_attributes(state: @decision, reviewed_by: actor, reviewed_at: Time.current, resolution_notes: @notes)
      changes = @report.changes
      ContentReport.transaction do
        @report.save!
        AuditEvent.record!(actor: actor, action: "content_report.reviewed", subject: @report, changes: changes,
                           reason: @notes, metadata: { decision: @decision, target_type: @report.target.class.name })
      end
      @report
    end
  end
end
