class CreateDogs < ActiveRecord::Migration[8.1]
  def change
    create_table :dogs do |t|
      t.string :name
      t.integer :age
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :dogs, :deleted_at
  end
end
