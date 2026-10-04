# O relato fica no Alert; Publication conserva identidade, interações e decisão de divulgação.
class UnifyOccurrencePublications < ActiveRecord::Migration[8.1]
  OLD_PUBLISHED = "state <> 'published' OR (review_status = 'approved' AND reviewed_content_version IS NOT NULL AND reviewed_content_version = content_version AND published_at IS NOT NULL)"
  OLD_REVIEW = "review_status NOT IN ('approved', 'rejected') OR (reviewed_by_id IS NOT NULL AND reviewed_at IS NOT NULL AND reviewed_content_version IS NOT NULL)"

  def up
    add_column :alerts, :location_description, :string
    remove_check_constraint :alerts, name: "alerts_manual_location"
    add_check_constraint :alerts, "location_source <> 'manual' OR (latitude IS NULL AND (location_id IS NOT NULL OR (location_description IS NOT NULL AND length(trim(location_description)) BETWEEN 3 AND 160)))", name: "alerts_manual_location"
    add_column :users, :verified_at, :datetime
    add_reference :users, :verified_by, foreign_key: { to_table: :users }
    add_check_constraint :users, "(verified_at IS NULL AND verified_by_id IS NULL) OR (verified_at IS NOT NULL AND verified_by_id IS NOT NULL)", name: "users_verification_pair"
    add_column :publications, :approval_method, :string
    add_column :publications, :moderation_blocked, :boolean, default: false, null: false
    remove_check_constraint :publications, name: "publications_published_requires_approval"
    remove_check_constraint :publications, name: "publications_review_fields"
    remove_check_constraint :publications, name: "publications_title_length"
    remove_check_constraint :publications, name: "publications_body_length"
    change_column_null :publications, :title, true
    change_column_null :publications, :body, true
    execute "UPDATE publications SET approval_method = 'administrator' WHERE review_status = 'approved'"

    # Não troca silenciosamente um texto editorial já aprovado pelo relato/fotos originais.
    # O conteúdo anterior fica apenas no histórico privado, inclusive para rollback.
    select_all("SELECT * FROM publications WHERE kind = 'occurrence'").each do |row|
      snapshot = row.slice("title", "body", "author_id", "state", "visibility", "review_status", "content_version", "reviewed_content_version", "reviewed_by_id", "reviewed_at", "review_reason", "published_at", "withdrawn_at", "source_changed_at")
      now = quote(Time.current)
      execute <<~SQL
        INSERT INTO audit_events (actor_id, action, subject_type, subject_id, changeset, metadata, reason, created_at)
        VALUES (NULL, 'system.occurrence_unified', 'Publication', #{row.fetch('id')}, '{}', #{quote({ legacy_editorial: snapshot }.to_json)},
                'Conteúdo anterior preservado; divulgação exige nova solicitação ou revisão.', #{now})
      SQL
      execute <<~SQL
        UPDATE publications SET title = NULL, body = NULL,
          author_id = (SELECT author_id FROM alerts WHERE alerts.id = publications.alert_id),
          moderation_blocked = #{row['state'] == 'withdrawn' ? 1 : 0},
          state = 'withdrawn', withdrawn_at = #{now}, visibility = 'internal',
          review_status = 'not_submitted', approval_method = NULL, reviewed_by_id = NULL,
          reviewed_at = NULL, reviewed_content_version = NULL, source_changed_at = NULL
        WHERE id = #{row.fetch('id')}
      SQL
    end
    add_check_constraint :publications, "(kind = 'occurrence' AND title IS NULL AND body IS NULL) OR (kind <> 'occurrence' AND title IS NOT NULL AND length(trim(title)) BETWEEN 5 AND 160 AND body IS NOT NULL AND length(trim(body)) BETWEEN 10 AND 10000)", name: "publications_canonical_content"
    add_check_constraint :publications, "approval_method IS NULL OR approval_method IN ('administrator', 'verified_author')", name: "publications_approval_method"
    add_check_constraint :publications, "review_status NOT IN ('approved', 'rejected') OR (reviewed_at IS NOT NULL AND reviewed_content_version IS NOT NULL AND (reviewed_by_id IS NOT NULL OR (review_status = 'approved' AND approval_method = 'verified_author')))", name: "publications_review_fields"
    add_check_constraint :publications, "state <> 'published' OR (published_at IS NOT NULL AND ((kind = 'occurrence' AND visibility = 'internal') OR (review_status = 'approved' AND reviewed_content_version = content_version)))", name: "publications_published_requires_approval"
  end

  def down
    # Registros sem referência no catálogo não cabem no esquema anterior.
    if select_value("SELECT count(*) FROM alerts WHERE location_source = 'manual' AND location_id IS NULL").to_i.positive?
      raise ActiveRecord::IrreversibleMigration, "há locais descritivos; restaure o backup para voltar ao esquema anterior"
    end
    remove_check_constraint :publications, name: "publications_canonical_content"
    remove_check_constraint :publications, name: "publications_approval_method"
    remove_check_constraint :publications, name: "publications_published_requires_approval"
    remove_check_constraint :publications, name: "publications_review_fields"
    execute "UPDATE publications SET title = (SELECT title FROM alerts WHERE alerts.id = publications.alert_id), body = (SELECT description FROM alerts WHERE alerts.id = publications.alert_id) WHERE kind = 'occurrence'"
    select_all("SELECT subject_id, metadata FROM audit_events WHERE action = 'system.occurrence_unified'").each do |event|
      snapshot = JSON.parse(event.fetch("metadata")).fetch("legacy_editorial")
      assignments = snapshot.map { |key, value| "#{quote_column_name(key)} = #{quote(value)}" }.join(", ")
      execute "UPDATE publications SET #{assignments} WHERE id = #{event.fetch('subject_id')}"
    end
    execute "UPDATE publications SET state = 'draft', review_status = 'not_submitted' WHERE reviewed_by_id IS NULL OR review_status <> 'approved' OR reviewed_content_version <> content_version"
    change_column_null :publications, :title, false
    change_column_null :publications, :body, false
    add_check_constraint :publications, "length(trim(title)) BETWEEN 5 AND 160", name: "publications_title_length"
    add_check_constraint :publications, "length(trim(body)) BETWEEN 10 AND 10000", name: "publications_body_length"
    add_check_constraint :publications, OLD_REVIEW, name: "publications_review_fields"
    add_check_constraint :publications, OLD_PUBLISHED, name: "publications_published_requires_approval"
    remove_column :publications, :moderation_blocked
    remove_column :publications, :approval_method
    remove_check_constraint :users, name: "users_verification_pair"
    remove_reference :users, :verified_by, foreign_key: { to_table: :users }
    remove_column :users, :verified_at
    remove_check_constraint :alerts, name: "alerts_manual_location"
    remove_column :alerts, :location_description
    add_check_constraint :alerts, "location_source <> 'manual' OR (location_id IS NOT NULL AND latitude IS NULL)", name: "alerts_manual_location"
  end
end
