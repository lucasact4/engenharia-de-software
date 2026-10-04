# Ordem das fotos pertence à ocorrência; ponto no mapa não é tratado como captura GPS.
class AddOccurrencePhotoOrderAndMapLocation < ActiveRecord::Migration[8.1]
  def up
    add_column :alerts, :photo_order, :json, default: [], null: false
    remove_check_constraint :alerts, name: "alerts_location_source"
    add_check_constraint :alerts, "location_source IN ('gps', 'map', 'manual', 'unavailable')", name: "alerts_location_source"
    remove_check_constraint :alerts, name: "alerts_gps_coordinates"
    add_check_constraint :alerts, "location_source NOT IN ('gps', 'map') OR latitude IS NOT NULL", name: "alerts_gps_coordinates"
  end

  def down
    if select_value("SELECT count(*) FROM alerts WHERE location_source = 'map'").to_i.positive?
      raise ActiveRecord::IrreversibleMigration, "há pontos selecionados no mapa; restaure um backup compatível"
    end
    remove_check_constraint :alerts, name: "alerts_gps_coordinates"
    add_check_constraint :alerts, "location_source <> 'gps' OR latitude IS NOT NULL", name: "alerts_gps_coordinates"
    remove_check_constraint :alerts, name: "alerts_location_source"
    add_check_constraint :alerts, "location_source IN ('gps', 'manual', 'unavailable')", name: "alerts_location_source"
    remove_column :alerts, :photo_order
  end
end
