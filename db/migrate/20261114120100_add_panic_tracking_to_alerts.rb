class AddPanicTrackingToAlerts < ActiveRecord::Migration[8.1]
  def change
    add_column :alerts, :panic_tracking_stopped_at, :datetime
    add_column :alerts, :panic_latest_position, :json
  end
end
