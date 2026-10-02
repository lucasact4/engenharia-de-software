module ContentReports
  # O denunciante reabre a própria denúncia já decidida, com novas informações explícitas.
  class Reopen < ApplicationService
    attr_reader :actor

    def initialize(actor:, report:, details:)
      @actor = actor
      @report = report
      @details = details
    end

    def call
      authorize!(@report, :reopen?)
      require_reason!(@details, @report)

      @report.assign_attributes(state: "pending", details: @details)
      changes = @report.changes.slice("state")
      ContentReport.transaction do
        @report.save!
        AuditEvent.record!(actor: actor, action: "content_report.reopened", subject: @report, changes: changes)
      end
      @report
    end
  end
end
