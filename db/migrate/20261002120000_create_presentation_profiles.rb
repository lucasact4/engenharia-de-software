class CreatePresentationProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :presentation_profiles do |t|
      t.string :name, null: false
      t.text :description
      t.string :delivery, null: false
      t.boolean :active, default: false, null: false
      t.json :selections, null: false

      t.timestamps
    end

    add_index :presentation_profiles, :name, unique: true
    # Só um perfil pode ser o padrão da apresentação pública.
    add_index :presentation_profiles, :active, unique: true, where: "active", name: "index_presentation_profiles_on_single_active"
  end
end
