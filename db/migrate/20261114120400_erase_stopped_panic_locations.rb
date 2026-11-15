class EraseStoppedPanicLocations < ActiveRecord::Migration[8.1]
  def up
    execute "PRAGMA secure_delete = ON"
    execute <<~SQL
      UPDATE alerts
      SET latitude = NULL, longitude = NULL, location_accuracy_meters = NULL,
          location_captured_at = NULL, location_description = NULL, location_id = NULL,
          location_unavailable_reason = NULL, panic_latest_position = NULL,
          location_source = 'unavailable',
          panic_tracking_stopped_at = COALESCE(panic_tracking_stopped_at, closed_at, resolved_at, updated_at)
      WHERE kind = 'panic' AND (panic_tracking_stopped_at IS NOT NULL OR status IN ('resolved', 'closed'))
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "As posições removidas não podem ser recuperadas por migração"
  end
end
