module Security
  class PresenceController < PortalController
    def create
      authorize Current.user, :update_security_presence?
      presence = Current.user.security_presence || Current.user.build_security_presence
      presence.assign_attributes(
        latitude: params.require(:latitude), longitude: params.require(:longitude), reported_at: Time.current
      )
      presence.save!
      head :no_content
    rescue ActiveRecord::RecordInvalid => error
      render json: { error: error.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end

    def destroy
      authorize Current.user, :update_security_presence?
      Current.user.security_presence&.destroy!
      head :no_content
    end
  end
end
