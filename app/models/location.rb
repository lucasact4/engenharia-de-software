# Local do campus para seleção manual; o catálogo aguarda os dados oficiais.
# As coordenadas de referência descrevem o local, nunca a captura GPS de um relato.
class Location < ApplicationRecord
  include CatalogEntry

  has_many :alerts, dependent: :restrict_with_exception

  validates :name, presence: true, length: { maximum: 120 }
  validates :description, length: { maximum: 500 }
  validates :reference_latitude, numericality: { in: -90..90 }, allow_nil: true
  validates :reference_longitude, numericality: { in: -180..180 }, allow_nil: true
  validate :reference_coordinates_pair
  validate :boundary_is_a_valid_polygon

  def boundary_geojson
    boundary.present? ? JSON.generate(boundary) : ""
  end

  def boundary_geojson=(value)
    @invalid_boundary_geojson = false
    self.boundary = value.blank? ? nil : JSON.parse(value)
  rescue JSON::ParserError, TypeError
    self.boundary = nil
    @invalid_boundary_geojson = true
  end

  def in_use?
    alerts.exists?
  end

  private

    def reference_coordinates_pair
      return if reference_latitude.nil? == reference_longitude.nil?

      errors.add(:base, :reference_coordinates_pair)
    end

    def boundary_is_a_valid_polygon
      if @invalid_boundary_geojson
        errors.add(:boundary, "não contém um GeoJSON válido")
        return
      end

      return if boundary.nil?

      ring = boundary.is_a?(Hash) && boundary["type"] == "Polygon" && boundary.dig("coordinates", 0)
      valid_ring = ring.is_a?(Array) && ring.length >= 4 && ring.first == ring.last && ring.all? do |point|
        point.is_a?(Array) && point.length == 2 &&
          point[0].is_a?(Numeric) && point[0].between?(-180, 180) &&
          point[1].is_a?(Numeric) && point[1].between?(-90, 90)
      end

      errors.add(:boundary, "deve ser um polígono GeoJSON fechado com coordenadas válidas") unless valid_ring
    end
end
