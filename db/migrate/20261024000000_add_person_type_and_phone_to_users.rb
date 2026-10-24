class AddPersonTypeAndPhoneToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :person_type, :string, null: false, default: "natural"
    add_column :users, :phone, :text
    add_index :users, :phone, unique: true, where: "phone IS NOT NULL"
  end
end
