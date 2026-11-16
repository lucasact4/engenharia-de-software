module NotificationsHelper
  def notification_feed
    @notification_feed ||= Notification.visible_to(Current.user)
  end

  def notification_destination(notification)
    case notification.kind
    when "panic" then handling_alert_path(notification.alert_id)
    when "alert_status" then alert_path(notification.alert_id)
    when "content_report" then admin_content_report_path(notification.content_report_id)
    when "publication_pending" then admin_publication_path(notification.publication_id)
    when "publication_status"
      notification.publication.alert_id ? alert_path(notification.publication.alert_id) : (Current.user.admin? ? admin_publication_path(notification.publication_id) : publications_path)
    else
      publication_path(notification.publication_id, anchor: notification.comment_id ? "comment_#{notification.comment_id}" : nil)
    end
  end
end
