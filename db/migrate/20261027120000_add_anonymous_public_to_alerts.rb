class AddAnonymousPublicToAlerts < ActiveRecord::Migration[8.1]
  def change
    add_column :alerts, :anonymous_public, :boolean, default: false, null: false
  end
end