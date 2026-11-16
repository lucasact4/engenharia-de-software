# Persistida na mesma transação do evento; leitura e entrega nunca concedem acesso ao alvo.
class Notification < ApplicationRecord
  KINDS = %w[alert_status publication_status comment like panic content_report publication_pending nearby_alert].freeze

  belongs_to :user
  belongs_to :alert, optional: true
  belongs_to :publication, optional: true
  belongs_to :comment, optional: true
  belongs_to :content_report, optional: true
  after_create { Notifications::Outbox.queue(self) }

  validates :event_key, :message, presence: true
  validates :kind, inclusion: { in: KINDS }

  scope :unread, -> { where(read_at: nil) }
  scope :prioritized, -> { order(Arel.sql("CASE WHEN notifications.kind = 'panic' AND notifications.read_at IS NULL THEN 0 ELSE 1 END"), created_at: :desc, id: :desc) }

  def urgent? = kind == "panic"

  def anonymous_author_notice?
    source = alert || publication&.alert
    source&.anonymous_public? && source.author_id == user_id
  end

  # Reavalia audiência, validade e papéis a cada consulta, inclusive após revogação.
  def self.visible_to(user)
    return none unless user&.active?

    own = where(user_id: user.id)
    alerts = AlertPolicy::Scope.new(user, Alert.all).resolve.select(:id)
    feed = PublicationPolicy::FeedScope.new(user, Publication.all).resolve.select(:id)
    visible = own.where(kind: "alert_status", alert_id: alerts)
      .or(own.where(kind: "publication_status", publication_id: Publication.where(author_id: user.id).select(:id)))
      .or(own.where(kind: %w[comment like nearby_alert], publication_id: feed, comment_id: nil))
      .or(own.where(kind: %w[comment like], publication_id: feed, comment_id: Comment.visible_content.select(:id)))
    visible = visible.or(own.where(kind: "panic", alert_id: alerts)) if user.admin? || user.role?(:security)
    visible = visible.or(own.where(kind: %w[content_report publication_pending])) if user.admin?
    visible
  end
end
