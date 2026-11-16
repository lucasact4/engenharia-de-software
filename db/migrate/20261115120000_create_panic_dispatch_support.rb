class CreatePanicDispatchSupport < ActiveRecord::Migration[8.1]
  def change
    create_table :security_presences do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.decimal :latitude, precision: 10, scale: 7, null: false
      t.decimal :longitude, precision: 10, scale: 7, null: false
      t.datetime :reported_at, null: false
      t.timestamps
      t.check_constraint "latitude >= -90 AND latitude <= 90", name: "security_presences_latitude_range"
      t.check_constraint "longitude >= -180 AND longitude <= 180", name: "security_presences_longitude_range"
    end

    create_table :security_push_subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.text :endpoint, null: false
      t.string :p256dh, null: false
      t.string :auth, null: false
      t.timestamps
      t.index :endpoint, unique: true
      t.index [ :user_id, :created_at ]
    end
  end
end
