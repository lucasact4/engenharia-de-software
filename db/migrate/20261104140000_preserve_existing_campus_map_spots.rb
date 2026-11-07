# Existing map spots remain visible through the new map-specific approval gate.
class PreserveExistingCampusMapSpots < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE publications
      SET campus_map_approved_at = COALESCE(publications.published_at, publications.updated_at, CURRENT_TIMESTAMP)
      FROM alerts
      WHERE alerts.id = publications.alert_id
        AND publications.kind = 'occurrence'
        AND publications.state = 'published'
        AND publications.visibility = 'public_external'
        AND publications.review_status = 'approved'
        AND publications.reviewed_content_version = publications.content_version
        AND publications.moderation_blocked = FALSE
        AND publications.campus_map_approved_at IS NULL
        AND alerts.kind = 'occurrence'
        AND alerts.requested_visibility = 'public_external'
        AND alerts.publication_blocked = FALSE
        AND alerts.status IN ('received', 'triaging', 'in_progress', 'awaiting_information')
    SQL
  end

  # The backfill preserves posts already visible on the map; rolling back should not hide them.
  def down
  end
end
