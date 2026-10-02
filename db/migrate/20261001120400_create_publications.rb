# Conteúdo editorial próprio, sem cópia de autoria, localização ou fotos operacionais.
class CreatePublications < ActiveRecord::Migration[8.1]
  def change
    create_table :publications do |t|
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.references :alert, foreign_key: true, index: { unique: true }
      t.string :kind, null: false
      t.string :title, null: false
      t.text :body, null: false
      t.string :visibility, null: false

      t.string :review_status, null: false, default: "not_submitted"
      t.string :state, null: false, default: "draft"
      # Toda edição relevante incrementa content_version; a aprovação registra a versão revisada.
      t.integer :content_version, null: false, default: 1
      t.integer :reviewed_content_version
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.datetime :reviewed_at
      t.text :review_reason

      t.datetime :published_at
      t.datetime :expires_at
      t.datetime :withdrawn_at
      # Assinala que o Alert de origem mudou depois da aprovação e precisa de revisão editorial.
      t.datetime :source_changed_at
      t.boolean :comments_enabled, null: false, default: true
      t.integer :lock_version, null: false, default: 0
      t.timestamps

      t.index %i[state visibility published_at]

      t.check_constraint "kind IN ('occurrence', 'notice', 'news')", name: "publications_kind"
      t.check_constraint "visibility IN ('internal', 'public_external')", name: "publications_visibility"
      t.check_constraint "review_status IN ('not_submitted', 'pending', 'approved', 'rejected')",
                         name: "publications_review_status"
      t.check_constraint "state IN ('draft', 'published', 'withdrawn')", name: "publications_state"
      t.check_constraint "(kind = 'occurrence' AND alert_id IS NOT NULL) OR (kind <> 'occurrence' AND alert_id IS NULL)",
                         name: "publications_alert_source"
      t.check_constraint "length(trim(title)) BETWEEN 5 AND 160", name: "publications_title_length"
      t.check_constraint "length(trim(body)) BETWEEN 10 AND 10000", name: "publications_body_length"
      t.check_constraint "review_status NOT IN ('approved', 'rejected') OR " \
                         "(reviewed_by_id IS NOT NULL AND reviewed_at IS NOT NULL AND reviewed_content_version IS NOT NULL)",
                         name: "publications_review_fields"
      t.check_constraint "review_status <> 'rejected' OR (review_reason IS NOT NULL AND length(trim(review_reason)) > 0)",
                         name: "publications_rejection_reason"
      t.check_constraint "state <> 'published' OR (review_status = 'approved' AND reviewed_content_version IS NOT NULL " \
                         "AND reviewed_content_version = content_version AND published_at IS NOT NULL)",
                         name: "publications_published_requires_approval"
      t.check_constraint "state <> 'withdrawn' OR withdrawn_at IS NOT NULL", name: "publications_withdrawn_at"
      t.check_constraint "kind <> 'notice' OR state <> 'published' OR expires_at IS NOT NULL",
                         name: "publications_notice_expires"
      t.check_constraint "expires_at IS NULL OR published_at IS NULL OR expires_at > published_at",
                         name: "publications_expires_after_publication"
      t.check_constraint "content_version >= 1 AND lock_version >= 0", name: "publications_versions"
    end
  end
end
