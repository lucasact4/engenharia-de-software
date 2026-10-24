class AddSearchIdentityFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :business_name, :string
    add_column :users, :mother_name, :string
    add_column :users, :cpf, :text
    add_column :users, :cnpj, :text

    add_index :users, :cpf, unique: true, where: "cpf IS NOT NULL"
    add_index :users, :cnpj, unique: true, where: "cnpj IS NOT NULL"
  end
end
