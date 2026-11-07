# Stores map approval separately from the post's existing mural approval.
class AddCampusMapApprovalToPublications < ActiveRecord::Migration[8.1]
  def up
    add_column :publications, :campus_map_approved_at, :datetime unless column_exists?(:publications, :campus_map_approved_at)
    unless column_exists?(:publications, :campus_map_approved_by_id)
      add_reference :publications, :campus_map_approved_by, foreign_key: { to_table: :users }
    end
    unless foreign_key_exists?(:publications, :users, column: :campus_map_approved_by_id)
      add_foreign_key :publications, :users, column: :campus_map_approved_by_id
    end
  end

  def down
    remove_foreign_key :publications, column: :campus_map_approved_by_id if foreign_key_exists?(:publications, :users, column: :campus_map_approved_by_id)
    remove_reference :publications, :campus_map_approved_by, index: true if column_exists?(:publications, :campus_map_approved_by_id)
    remove_column :publications, :campus_map_approved_at if column_exists?(:publications, :campus_map_approved_at)
  end
end
