module Publications
  class SyncWithSource < ApplicationService
    attr_reader :actor
    def initialize(actor:, alert:)
      @actor, @alert = actor, alert
    end
    def call
      SyncOccurrence.call(actor: actor, alert: @alert, request_external: true)
    end
  end
end
