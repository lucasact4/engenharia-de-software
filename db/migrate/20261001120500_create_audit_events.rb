# Auditoria protegida na API; alvo polimórfico não tem FK e SQL direto pode alterar a tabela.
class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events do |t|
      t.references :actor, foreign_key: { to_table: :users }, index: false
      t.string :action, null: false
      t.string :subject_type, null: false
      t.bigint :subject_id, null: false
      t.text :reason
      t.json :changeset, null: false, default: {}
      t.json :metadata, null: false, default: {}
      t.datetime :created_at, null: false

      t.index %i[subject_type subject_id created_at], name: "index_audit_events_on_subject_and_created_at"
      t.index %i[actor_id created_at]
      t.index %i[action created_at]

      # Ator nulo somente em evento técnico identificado (prefixo "system.").
      t.check_constraint "actor_id IS NOT NULL OR action LIKE 'system.%'", name: "audit_events_actor_required"
      t.check_constraint "length(action) BETWEEN 3 AND 80", name: "audit_events_action_length"
      t.check_constraint "reason IS NULL OR length(reason) <= 1000", name: "audit_events_reason_length"
    end
  end
end
