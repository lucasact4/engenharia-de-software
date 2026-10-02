# Local do campus para seleção manual; o catálogo aguarda os dados oficiais.
class Location < ApplicationRecord
  include CatalogEntry

  has_many :alerts, dependent: :restrict_with_exception

  validates :name, presence: true, length: { maximum: 120 }
  validates :reference_latitude, numericality: { in: -90..90 }, allow_nil: true
  validates :reference_longitude, numericality: { in: -180..180 }, allow_nil: true
  validate :reference_coordinates_pair

  private

    def reference_coordinates_pair
      return if reference_latitude.nil? == reference_longitude.nil?

      errors.add(:base, :reference_coordinates_pair)
    end
end
