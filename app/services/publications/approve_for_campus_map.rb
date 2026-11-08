# Adds an administrator's map approval to the existing mural publication.
module Publications
  class ApproveForCampusMap < ApplicationService
    attr_reader :actor

    def initialize(actor:, publication:, lock_version: nil)
      @actor = actor
      @publication = publication
      @lock_version = lock_version
    end

    def call
      authorize!(@publication, :approve_for_campus_map?)
      apply_lock_version(@publication, @lock_version)

      Publication.transaction do
        @publication.update!(campus_map_approved_at: Time.current, campus_map_approved_by: actor)
        AuditEvent.record!(actor: actor, action: "publication.campus_map_approved", subject: @publication,
                           changes: @publication.saved_changes.slice("campus_map_approved_at", "campus_map_approved_by_id"))
      end
      @publication
    end
  end
end
