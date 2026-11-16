# Compatibilidade com tarefas já enfileiradas. A entrega usa Notifications::Outbox.
class AlertUpdateNotificationJob < ApplicationJob
  def perform(_alert_id)
  end
end
