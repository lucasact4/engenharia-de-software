class EncryptSguPersonalData < ActiveRecord::Migration[8.1]
  def up
    execute "PRAGMA secure_delete = ON"

    change_table :users, bulk: true do |table|
      table.remove_check_constraint name: "users_bio_length"
      table.remove_check_constraint name: "users_display_name_length"
      table.remove_check_constraint name: "users_username_length_and_case"
      table.change :email_address, :text, null: false
      table.change :username, :text
      table.change :display_name, :text
      table.change :mother_name, :text
      table.change :business_name, :text
    end

    change_table :alerts, bulk: true do |table|
      table.remove_check_constraint name: "alerts_category_other_description_length"
      table.remove_check_constraint name: "alerts_description_length"
      table.remove_check_constraint name: "alerts_title_length"
      table.remove_check_constraint name: "alerts_latitude_range"
      table.remove_check_constraint name: "alerts_longitude_range"
      table.remove_check_constraint name: "alerts_occurrence_required_fields"
      table.remove_check_constraint name: "alerts_location_accuracy"
      table.remove_check_constraint name: "alerts_manual_location"
      table.check_constraint "kind <> 'occurrence' OR (title IS NOT NULL AND description IS NOT NULL AND category_id IS NOT NULL AND location_source <> 'unavailable')", name: "alerts_occurrence_required_fields"
      table.check_constraint "location_accuracy_meters IS NULL OR location_source = 'gps'", name: "alerts_location_accuracy"
      table.check_constraint "location_source <> 'manual' OR (latitude IS NULL AND (location_id IS NOT NULL OR location_description IS NOT NULL))", name: "alerts_manual_location"
      table.change :title, :text
      table.change :category_other_description, :text
      table.change :latitude, :text
      table.change :longitude, :text
      table.change :location_accuracy_meters, :text
      table.change :location_captured_at, :text
      table.change :location_description, :text
      table.change :panic_latest_position, :text
    end

    change_table :publications, bulk: true do |table|
      table.remove_check_constraint name: "publications_canonical_content"
      table.remove_check_constraint name: "publications_rejection_reason"
      table.check_constraint "(kind = 'occurrence' AND title IS NULL AND body IS NULL) OR (kind <> 'occurrence' AND title IS NOT NULL AND body IS NOT NULL)", name: "publications_canonical_content"
      table.check_constraint "review_status <> 'rejected' OR review_reason IS NOT NULL", name: "publications_rejection_reason"
      table.change :title, :text
    end

    change_table :comments, bulk: true do |table|
      table.remove_check_constraint name: "comments_body_length"
      table.remove_check_constraint name: "comments_removal_fields"
      table.check_constraint "removed_at IS NULL OR (removed_by_id IS NOT NULL AND removal_reason IS NOT NULL)", name: "comments_removal_fields"
    end

    change_table :content_reports, bulk: true do |table|
      table.remove_check_constraint name: "content_reports_details_length"
      table.remove_check_constraint name: "content_reports_other_details"
      table.check_constraint "reason <> 'other' OR details IS NOT NULL", name: "content_reports_other_details"
    end

    change_table :audit_events, bulk: true do |table|
      table.remove_check_constraint name: "audit_events_reason_length"
    end

    change_table :sessions, bulk: true do |table|
      table.change :ip_address, :text
      table.change :user_agent, :text
    end

    execute <<~SQL
      UPDATE alerts
      SET panic_latest_position = NULL,
          panic_tracking_stopped_at = COALESCE(panic_tracking_stopped_at, closed_at, resolved_at, updated_at)
      WHERE kind = 'panic' AND (panic_tracking_stopped_at IS NOT NULL OR status IN ('resolved', 'closed'))
    SQL

    encrypt_existing(User, %w[email_address username display_name mother_name business_name bio registration_review_reason])
    encrypt_existing(Alert, %w[title description category_other_description closure_notes latitude longitude location_accuracy_meters location_captured_at location_description panic_latest_position])
    encrypt_existing(Publication, %w[title body review_reason])
    encrypt_existing(Comment, %w[body removal_reason])
    encrypt_existing(ContentReport, %w[details])
    encrypt_existing(AuditEvent, %w[reason])
    encrypt_existing(Session, %w[ip_address user_agent])
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Restaurar uma cópia anterior requer o procedimento de recuperação do SGU"
  end

  private

    def encrypt_existing(model, fields)
      model.reset_column_information
      columns = fields.map { |field| connection.quote_column_name(field) }.join(", ")
      last_id = 0
      loop do
        table = connection.quote_table_name(model.table_name)
        rows = connection.select_all("SELECT id, #{columns} FROM #{table} WHERE id > #{last_id} ORDER BY id LIMIT 500")
        break if rows.empty?

        rows.each do |row|
          values = fields.filter_map do |field|
            raw = row.fetch(field)
            next if raw.nil?

            type = model.type_for_attribute(field)
            next if type.encrypted?(raw)

            value = field == "panic_latest_position" ? JSON.parse(raw) : type.cast(raw)
            "#{connection.quote_column_name(field)} = #{connection.quote(type.serialize(value))}"
          end
          id = Integer(row.fetch("id"))
          connection.execute("UPDATE #{table} SET #{values.join(', ')} WHERE id = #{id}") if values.any?
        end
        last_id = Integer(rows.last.fetch("id"))
      end
    end
end
