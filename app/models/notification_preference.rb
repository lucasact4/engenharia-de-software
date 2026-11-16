class NotificationPreference < ApplicationRecord
  belongs_to :user
  belongs_to :location, optional: true

  validate :location_available, if: :will_save_change_to_location_id?

  private

    def location_available
      return if location_id.nil? || Notifications::Nearby.selectable_locations.exists?(location_id)

      errors.add(:location, "selecione um local com posição cadastrada")
    end
end
