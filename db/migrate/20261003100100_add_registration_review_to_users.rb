# Contas existentes permanecem aprovadas; revisão de cadastro é independente dos papéis.
class AddRegistrationReviewToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :registration_status, :string, null: false, default: "approved"
    add_column :users, :registration_role_code, :string
    add_column :users, :registration_reviewed_at, :datetime
    add_column :users, :registration_review_reason, :text
    add_column :users, :email_verified_at, :datetime
    add_reference :users, :registration_reviewed_by, foreign_key: { to_table: :users }
    add_index :users, [ :registration_status, :created_at ]
    add_check_constraint :users, "registration_status IN ('pending', 'approved', 'rejected')", name: "users_registration_status_valid"
    add_check_constraint :users, "registration_role_code IS NULL OR registration_role_code IN ('visitor', 'professor', 'student')", name: "users_registration_role_valid"
  end
end
