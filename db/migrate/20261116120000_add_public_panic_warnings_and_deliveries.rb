class AddPublicPanicWarningsAndDeliveries < ActiveRecord::Migration[8.1]
  def change
    add_column :alerts, :public_warning, :boolean, null: false, default: false
    add_column :alerts, :public_warning_withdrawn_at, :datetime
    add_reference :alerts, :public_warning_withdrawn_by, foreign_key: { to_table: :users }
    add_index :alerts, %i[kind public_warning created_at]

    create_table :panic_deliveries do |t|
      t.references :alert, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :channel, null: false
      t.string :status, null: false
      t.integer :latency_ms, null: false
      t.string :error_message
      t.timestamps
    end
    add_index :panic_deliveries, %i[alert_id created_at]
  end
end
