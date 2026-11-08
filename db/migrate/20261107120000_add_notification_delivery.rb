class AddNotificationDelivery < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :notifications,
      "kind IN ('alert_status', 'publication_status', 'comment', 'like', 'panic', 'content_report', 'publication_pending')",
      name: "notifications_kind"
    add_check_constraint :notifications,
      "kind IN ('alert_status', 'publication_status', 'comment', 'like', 'panic', 'content_report', 'publication_pending', 'nearby_alert')",
      name: "notifications_kind"

    create_table :notification_preferences do |t|
      t.references :user, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.references :location, foreign_key: { on_delete: :nullify }
      t.boolean :email_enabled, null: false, default: false
      t.timestamps
    end

    create_table :push_subscriptions do |t|
      t.references :session, null: false, foreign_key: { on_delete: :cascade }
      t.string :endpoint_digest, null: false, index: { unique: true }
      t.text :endpoint, null: false
      t.text :p256dh, null: false
      t.text :auth, null: false
      t.timestamps
    end

    create_table :notification_deliveries do |t|
      t.references :notification, null: false, foreign_key: { on_delete: :cascade }
      t.references :push_subscription, foreign_key: { on_delete: :cascade }
      t.string :channel, null: false
      t.integer :attempts, null: false, default: 0
      t.datetime :available_at, null: false
      t.datetime :finished_at
      t.string :result
      t.timestamps
      t.index :notification_id, unique: true, where: "channel = 'email'", name: "index_notification_deliveries_email"
      t.index %i[notification_id push_subscription_id], unique: true, where: "channel = 'push'", name: "index_notification_deliveries_push"
      t.index %i[finished_at available_at]
      t.check_constraint "(channel = 'email' AND push_subscription_id IS NULL) OR (channel = 'push' AND push_subscription_id IS NOT NULL)", name: "notification_deliveries_destination"
    end
  end
end
