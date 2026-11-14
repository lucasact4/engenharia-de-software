class RequireOccurrenceSeverityAndReviewAnonymousPosts < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :alerts, name: "alerts_reported_severity"
    add_check_constraint :alerts, "reported_severity IS NULL OR reported_severity IN ('low', 'moderate', 'high', 'critical', 'unsure')",
                         name: "alerts_reported_severity"
    execute <<~SQL
      UPDATE publications
      SET state = 'draft', visibility = 'internal', review_status = 'pending', approval_method = NULL,
          reviewed_content_version = NULL, reviewed_at = NULL, reviewed_by_id = NULL, review_reason = NULL,
          campus_map_approved_at = NULL, campus_map_approved_by_id = NULL
      WHERE kind = 'occurrence' AND state = 'published'
        AND alert_id IN (SELECT id FROM alerts WHERE anonymous_public = TRUE AND requested_visibility <> 'restricted' AND publication_blocked = FALSE)
        AND (approval_method IS NULL OR approval_method <> 'administrator'
             OR reviewed_content_version IS NULL OR reviewed_content_version <> content_version OR review_status <> 'approved')
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
