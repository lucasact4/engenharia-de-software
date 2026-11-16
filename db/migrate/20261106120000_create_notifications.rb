class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    # Sequência durável: reaberturas continuam distintas mesmo com timestamps iguais.
    add_column :content_reports, :notification_version, :integer, null: false, default: 0
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.string :event_key, null: false
      t.string :kind, null: false
      t.string :message, null: false
      t.references :alert, foreign_key: true
      t.references :publication, foreign_key: true
      t.references :comment, foreign_key: true
      t.references :content_report, foreign_key: true
      t.datetime :read_at
      t.timestamps
      t.index %i[user_id event_key], unique: true
      t.index %i[user_id read_at created_at]
      t.check_constraint "kind IN ('alert_status', 'publication_status', 'comment', 'like', 'panic', 'content_report', 'publication_pending')", name: "notifications_kind"
    end
  end
end
