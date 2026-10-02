# Perfis existentes continuam privados; nome, username e bio são opcionais e não vêm do e-mail.
class AddProfileFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :display_name, :string
    add_column :users, :username, :string
    add_column :users, :bio, :text
    add_column :users, :public_profile, :boolean, default: false, null: false

    # UNIQUE aceita vários NULL (SQLite e PostgreSQL): o username só é único quando informado.
    add_index :users, :username, unique: true

    add_check_constraint :users,
      "username IS NULL OR (length(username) BETWEEN 3 AND 30 AND username = lower(username))",
      name: "users_username_length_and_case"
    add_check_constraint :users,
      "display_name IS NULL OR length(display_name) BETWEEN 1 AND 80",
      name: "users_display_name_length"
    add_check_constraint :users,
      "bio IS NULL OR length(bio) <= 500",
      name: "users_bio_length"
  end
end
