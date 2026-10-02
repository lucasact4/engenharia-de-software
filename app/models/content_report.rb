# Denúncia de uma Publication ou de um Comment (exatamente um alvo).
class ContentReport < ApplicationRecord
  DETAILS_MAX = 2000

  enum :reason,
       { spam: "spam", harassment: "harassment", misinformation: "misinformation",
         privacy: "privacy", inappropriate: "inappropriate", other: "other" },
       prefix: :reason, validate: true
  enum :state, { pending: "pending", actioned: "actioned", dismissed: "dismissed" }, validate: true

  belongs_to :reporter, class_name: "User", inverse_of: :content_reports
  belongs_to :publication, optional: true
  belongs_to :comment, optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true

  normalizes :details, with: ->(details) { details.strip.presence }

  validates :details, length: { maximum: DETAILS_MAX }
  validates :details, presence: true, if: :reason_other?
  validates :publication_id, uniqueness: { scope: :reporter_id }, allow_nil: true
  validates :comment_id, uniqueness: { scope: :reporter_id }, allow_nil: true
  validates :reviewed_by, :reviewed_at, presence: true, unless: :pending?
  validate :single_target

  def target
    publication || comment
  end

  # Publication à qual o alvo pertence; o acesso à denúncia de comentário respeita a publicação.
  def target_publication
    publication || comment&.publication
  end

  private

    def single_target
      return if publication_id.present? ^ comment_id.present?

      errors.add(:base, :single_target)
    end
end
