module Security
  class PushSubscriptionsController < PortalController
    def create
      authorize Current.user, :manage_security_push_subscription?
      submitted = params.require(:subscription).permit(:endpoint, keys: %i[p256dh auth])
      keys = submitted.fetch(:keys)
      subscription = SecurityPushSubscription.find_or_initialize_by(endpoint: submitted.fetch(:endpoint))
      subscription.user = Current.user
      subscription.p256dh = keys.fetch(:p256dh)
      subscription.auth = keys.fetch(:auth)
      subscription.save!
      head :created
    rescue KeyError, ActionController::ParameterMissing => error
      render json: { error: error.message }, status: :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => error
      render json: { error: error.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end

    def destroy
      authorize Current.user, :manage_security_push_subscription?
      endpoint = params.require(:endpoint)
      Current.user.security_push_subscriptions.find_by(endpoint: endpoint)&.destroy!
      head :no_content
    end
  end
end
