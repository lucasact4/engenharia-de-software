# Catálogos institucionais; códigos conhecidos nas policies definem permissões.
class CreateRolesAndCatalogs < ActiveRecord::Migration[8.1]
  def change
    create_table :roles do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps

      t.index :code, unique: true
      t.check_constraint "length(code) BETWEEN 2 AND 40 AND code = lower(code)", name: "roles_code_format"
      t.check_constraint "length(name) BETWEEN 1 AND 80", name: "roles_name_length"
    end

    create_table :user_roles do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :role, null: false, foreign_key: true
      # Opcional apenas para bootstrap técnico; o serviço de concessão sempre informa o administrador.
      t.references :granted_by, foreign_key: { to_table: :users }
      t.timestamps

      t.index %i[user_id role_id], unique: true
    end

    create_table :categories do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.text :description
      # Exige explicação complementar no alerta (ex.: categoria "Outro").
      t.boolean :requires_details, null: false, default: false
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps

      t.index :code, unique: true
      t.index %i[active position]
      t.check_constraint "length(code) BETWEEN 2 AND 40 AND code = lower(code)", name: "categories_code_format"
      t.check_constraint "length(name) BETWEEN 1 AND 80", name: "categories_name_length"
    end

    # Catálogo de prédios/áreas para seleção manual. Sem dados oficiais, nasce vazio.
    # As coordenadas de referência indicam o centro aproximado do local, não o GPS de quem reporta.
    create_table :locations do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.decimal :reference_latitude, precision: 10, scale: 7
      t.decimal :reference_longitude, precision: 10, scale: 7
      t.timestamps

      t.index :code, unique: true
      t.index %i[active position]
      t.check_constraint "length(code) BETWEEN 2 AND 40 AND code = lower(code)", name: "locations_code_format"
      t.check_constraint "length(name) BETWEEN 1 AND 120", name: "locations_name_length"
      t.check_constraint "(reference_latitude IS NULL AND reference_longitude IS NULL) OR " \
                         "(reference_latitude IS NOT NULL AND reference_longitude IS NOT NULL)",
                         name: "locations_reference_pair"
      t.check_constraint "reference_latitude IS NULL OR (reference_latitude >= -90 AND reference_latitude <= 90)",
                         name: "locations_reference_latitude_range"
      t.check_constraint "reference_longitude IS NULL OR (reference_longitude >= -180 AND reference_longitude <= 180)",
                         name: "locations_reference_longitude_range"
    end
  end
end
