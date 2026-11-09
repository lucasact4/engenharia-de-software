class AddRelatedAlertToAlerts < ActiveRecord::Migration[8.1]
  def change
    add_reference :alerts, :related_alert, foreign_key: { to_table: :alerts }, index: true
  end
end
