class AddGoogleSubjectToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :google_subject, :text
    add_index :users, :google_subject, unique: true
  end
end
