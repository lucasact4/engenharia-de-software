class AddBoundaryToLocations < ActiveRecord::Migration[8.1]
  def change
    add_column :locations, :boundary, :json
  end
end
