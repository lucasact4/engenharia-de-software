class NotificationPolicy < ApplicationPolicy
  def index? = active_user?
  def read_all? = active_user?
  def read? = active_user? && Notification.visible_to(user).exists?(id: record.id)

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.merge(Notification.visible_to(user))
  end
end
