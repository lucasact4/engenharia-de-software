# Ocorrência e pânico compartilham a tabela, com regras condicionais.
# CHECKs usam IS NOT NULL porque, em SQLite, resultado NULL não rejeita a linha.
class CreateAlerts < ActiveRecord::Migration[8.1]
  def change
    create_table :alerts do |t|
      t.references :author, null: false, foreign_key: { to_table: :users }, index: false
      t.string :kind, null: false
      t.string :protocol, null: false

      t.string :title
      t.text :description
      t.references :category, foreign_key: true
      t.string :category_other_description

      t.string :location_source, null: false
      t.references :location, foreign_key: true
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
      t.decimal :location_accuracy_meters, precision: 10, scale: 2
      t.datetime :location_captured_at
      t.string :location_unavailable_reason

      t.string :requested_visibility, null: false
      t.string :visibility, null: false

      t.string :reported_severity
      t.string :assessed_severity
      t.string :priority

      t.string :status, null: false, default: "received"
      t.datetime :status_changed_at
      t.references :assigned_to, foreign_key: { to_table: :users }
      t.string :closure_reason
      t.text :closure_notes
      t.references :duplicate_of, foreign_key: { to_table: :alerts }
      t.datetime :resolved_at
      t.datetime :closed_at

      t.string :client_request_id
      t.string :client_request_digest
      t.integer :lock_version, null: false, default: 0
      t.timestamps

      t.index :protocol, unique: true
      t.index %i[author_id created_at]
      t.index %i[author_id client_request_id], unique: true, where: "client_request_id IS NOT NULL",
              name: "index_alerts_on_author_and_client_request"
      t.index %i[kind visibility status]
      t.index %i[status created_at]

      t.check_constraint "kind IN ('occurrence', 'panic')", name: "alerts_kind"
      t.check_constraint "location_source IN ('gps', 'manual', 'unavailable')", name: "alerts_location_source"
      t.check_constraint "requested_visibility IN ('internal', 'restricted', 'public_external')",
                         name: "alerts_requested_visibility"
      t.check_constraint "visibility IN ('internal', 'restricted')", name: "alerts_visibility"
      t.check_constraint "reported_severity IS NULL OR reported_severity IN ('low', 'moderate', 'high', 'critical')",
                         name: "alerts_reported_severity"
      t.check_constraint "assessed_severity IS NULL OR assessed_severity IN ('low', 'moderate', 'high', 'critical')",
                         name: "alerts_assessed_severity"
      t.check_constraint "priority IS NULL OR priority IN ('low', 'normal', 'high', 'urgent')", name: "alerts_priority"
      t.check_constraint "status IN ('received', 'triaging', 'in_progress', 'awaiting_information', 'resolved', 'closed')",
                         name: "alerts_status"
      t.check_constraint "closure_reason IS NULL OR closure_reason IN ('resolved', 'duplicate', 'invalid', 'out_of_scope', 'other')",
                         name: "alerts_closure_reason"
      t.check_constraint "location_unavailable_reason IS NULL OR location_unavailable_reason IN " \
                         "('permission_denied', 'position_unavailable', 'timeout', 'not_supported', 'not_shared')",
                         name: "alerts_location_unavailable_reason"

      # Ocorrência comum: título, descrição, categoria e localização obrigatórios.
      t.check_constraint "kind <> 'occurrence' OR (" \
                         "title IS NOT NULL AND length(trim(title)) >= 5 AND " \
                         "description IS NOT NULL AND length(trim(description)) >= 10 AND " \
                         "category_id IS NOT NULL AND location_source <> 'unavailable')",
                         name: "alerts_occurrence_required_fields"
      t.check_constraint "title IS NULL OR length(title) <= 160", name: "alerts_title_length"
      t.check_constraint "description IS NULL OR length(description) <= 5000", name: "alerts_description_length"
      t.check_constraint "category_other_description IS NULL OR length(category_other_description) <= 500",
                         name: "alerts_category_other_description_length"

      # Pânico: sempre restrito e com chave de idempotência do cliente.
      t.check_constraint "kind <> 'panic' OR (requested_visibility = 'restricted' AND visibility = 'restricted' " \
                         "AND client_request_id IS NOT NULL)",
                         name: "alerts_panic_restricted"
      # O registro operacional só é interno quando a solicitação é interna.
      t.check_constraint "visibility = 'restricted' OR requested_visibility = 'internal'",
                         name: "alerts_visibility_matches_request"

      # Localização.
      t.check_constraint "(latitude IS NULL AND longitude IS NULL) OR (latitude IS NOT NULL AND longitude IS NOT NULL)",
                         name: "alerts_coordinates_pair"
      t.check_constraint "latitude IS NULL OR (latitude >= -90 AND latitude <= 90)", name: "alerts_latitude_range"
      t.check_constraint "longitude IS NULL OR (longitude >= -180 AND longitude <= 180)", name: "alerts_longitude_range"
      t.check_constraint "location_source <> 'gps' OR latitude IS NOT NULL", name: "alerts_gps_coordinates"
      t.check_constraint "location_source <> 'manual' OR (location_id IS NOT NULL AND latitude IS NULL)",
                         name: "alerts_manual_location"
      t.check_constraint "location_source <> 'unavailable' OR (location_id IS NULL AND latitude IS NULL)",
                         name: "alerts_unavailable_location"
      t.check_constraint "location_accuracy_meters IS NULL OR (location_accuracy_meters >= 0 AND location_source = 'gps')",
                         name: "alerts_location_accuracy"
      t.check_constraint "location_captured_at IS NULL OR location_source = 'gps'", name: "alerts_location_captured_at"
      t.check_constraint "location_unavailable_reason IS NULL OR location_source = 'unavailable'",
                         name: "alerts_location_unavailable_reason_source"

      # Atendimento e encerramento.
      t.check_constraint "status <> 'resolved' OR resolved_at IS NOT NULL", name: "alerts_resolved_at"
      t.check_constraint "resolved_at IS NULL OR status IN ('resolved', 'closed')", name: "alerts_resolved_at_status"
      t.check_constraint "status <> 'closed' OR (closed_at IS NOT NULL AND closure_reason IS NOT NULL)",
                         name: "alerts_closed_fields"
      t.check_constraint "(closed_at IS NULL AND closure_reason IS NULL) OR status = 'closed'",
                         name: "alerts_closure_only_when_closed"
      t.check_constraint "closure_reason IS NULL OR closure_reason <> 'duplicate' OR duplicate_of_id IS NOT NULL",
                         name: "alerts_duplicate_target_required"
      t.check_constraint "duplicate_of_id IS NULL OR (closure_reason = 'duplicate' AND duplicate_of_id <> id)",
                         name: "alerts_duplicate_reference"

      t.check_constraint "client_request_id IS NULL OR (length(client_request_id) BETWEEN 8 AND 64 " \
                         "AND client_request_digest IS NOT NULL)",
                         name: "alerts_client_request"
      t.check_constraint "lock_version >= 0", name: "alerts_lock_version"
    end
  end
end
