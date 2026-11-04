class AddEmailNotificationPreferencesToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :email_notifications_enabled, :boolean, default: false, null: false
    add_column :users, :nearby_alerts_email_enabled, :boolean, default: false, null: false
    add_column :users, :nearby_alerts_radius_km, :integer, default: 5, null: false
    add_column :users, :email_notifications_consented_at, :datetime
    add_reference :users, :notification_location, foreign_key: { to_table: :locations }, index: true
    add_check_constraint :users, "nearby_alerts_radius_km BETWEEN 1 AND 25", name: "users_nearby_alert_radius"
  end
end
