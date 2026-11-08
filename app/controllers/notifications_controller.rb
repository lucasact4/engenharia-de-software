class NotificationsController < PortalController
  before_action :prevent_caching

  def index
    authorize Notification
    feed = policy_scope(Notification)
    @notifications = feed.prioritized.limit(50).offset([ params[:page].to_i - 1, 0 ].max * 50)
    @page = [ params[:page].to_i, 1 ].max
    respond_to do |format|
      format.html do
        @preference = NotificationPreference.find_or_initialize_by(user: Current.user)
        @nearby_locations = Notifications::Nearby.selectable_locations.order(:name)
      end
      format.json do
        urgent = feed.unread.where(kind: "panic").order(:created_at, :id).first
        preview = feed.prioritized.limit(10).to_a
        render json: {
          unread_count: feed.unread.count,
          list_version: Digest::SHA256.hexdigest(preview.map { |notification| [ notification.id, notification.read_at, notification.updated_at ] }.to_json),
          list_html: render_to_string(partial: "notifications/list", formats: [ :html ], locals: { notifications: preview }),
          urgent_id: urgent&.id,
          urgent_html: urgent ? render_to_string(partial: "notifications/urgent", formats: [ :html ], locals: { notification: urgent }) : nil
        }
      end
    end
  end

  def read
    notification = policy_scope(Notification).find(params[:id])
    authorize notification
    notification.class.where(id: notification.id, read_at: nil).update_all(read_at: Time.current)
    respond_to do |format|
      format.html { redirect_back fallback_location: notifications_path, status: :see_other }
      format.json { head :no_content }
    end
  end

  def read_all
    authorize Notification
    # Pânico exige reconhecimento explícito no popup ou no histórico.
    policy_scope(Notification).unread.where.not(kind: "panic").update_all(read_at: Time.current)
    redirect_to notifications_path, notice: "Notificações comuns marcadas como lidas.", status: :see_other
  end

  def preferences
    authorize Notification, :index?
    preference = NotificationPreference.find_or_create_by!(user: Current.user)
    attributes = params.expect(notification_preference: %i[email_enabled location_id])
    attributes.delete(:email_enabled) unless Notifications::ChannelConfig.email_available?
    if preference.update(attributes)
      redirect_to notifications_path, notice: "Preferências de notificações salvas.", status: :see_other
    else
      redirect_to notifications_path, alert: preference.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def subscribe_push
    authorize Notification, :index?
    return head :service_unavailable unless Notifications::ChannelConfig.push_available?

    subscription = params.expect(subscription: [ :endpoint, keys: %i[p256dh auth] ])
    keys = subscription.fetch(:keys, {})
    PushSubscription.register!(session: Current.session, endpoint: subscription[:endpoint], p256dh: keys[:p256dh], auth: keys[:auth])
    head :no_content
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_content
  end

  def unsubscribe_push
    authorize Notification, :index?
    Current.session.push_subscriptions.delete_all
    head :no_content
  end

  private

    def prevent_caching
      response.headers["Cache-Control"] = "no-store, private"
      response.headers["Vary"] = "Cookie"
    end
end
