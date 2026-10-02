# A restrição administrativa bloqueia a divulgação sem apagar a solicitação do autor.
class AddPublicationBlockToAlerts < ActiveRecord::Migration[8.1]
  def up
    add_column :alerts, :publication_blocked, :boolean, default: false, null: false
    add_check_constraint :alerts, "publication_blocked IN (0, 1)", name: "alerts_publication_blocked_boolean"

    # Recupera restrições já auditadas, desde que não tenham sido revertidas depois.
    execute <<~SQL
      UPDATE alerts SET publication_blocked = 1
      WHERE id IN (
        SELECT event.subject_id FROM audit_events event
        WHERE event.subject_type = 'Alert' AND event.action = 'alert.restricted'
          AND NOT EXISTS (
            SELECT 1 FROM audit_events newer
            WHERE newer.subject_type = 'Alert' AND newer.subject_id = event.subject_id
              AND newer.action IN ('alert.restricted', 'alert.audience_changed')
              AND newer.id > event.id
          )
      )
    SQL
  end

  def down
    remove_check_constraint :alerts, name: "alerts_publication_blocked_boolean"
    remove_column :alerts, :publication_blocked
  end
end
