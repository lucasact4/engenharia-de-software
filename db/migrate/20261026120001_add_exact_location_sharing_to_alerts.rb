class AddExactLocationSharingToAlerts < ActiveRecord::Migration[8.0]
  def change
    add_column :alerts, :share_exact_location, :boolean, default: false, null: false
  end
end
