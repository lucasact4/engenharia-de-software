# Post de ocorrência com conteúdo canônico no Alert; avisos e notícias conservam texto próprio.

class Publication < ApplicationRecord
  include TextSearch
  attribute :approval_method, :string
  enum :approval_method, { administrator: "administrator", verified_author: "verified_author" }, prefix: :approval, validate: { allow_nil: true }
  has_many_attached :photos
  before_validation :clear_occurrence_copy

  def title = occurrence? && alert ? alert.title : super
  def body = occurrence? && alert ? alert.description : super
  def feed_photos = occurrence? ? alert.photos : photos
  def ordered_feed_photos = occurrence? ? alert.ordered_photos : photos.to_a

  TITLE_LENGTH = 5..160
  BODY_LENGTH = 10..10_000
  RELEVANT_ATTRIBUTES = %w[title body visibility expires_at].freeze

  enum :kind, { occurrence: "occurrence", notice: "notice", news: "news" }, validate: true
  enum :visibility, { internal: "internal", public_external: "public_external" }, validate: true
  enum :review_status,
       { not_submitted: "not_submitted", pending: "pending", approved: "approved", rejected: "rejected" },
       prefix: :review, validate: true
  enum :state, { draft: "draft", published: "published", withdrawn: "withdrawn" }, validate: true

  belongs_to :author, class_name: "User", inverse_of: :authored_publications
  belongs_to :alert, optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true

  has_many :comments, dependent: :restrict_with_exception
  has_many :publication_likes, dependent: :destroy
  has_many :publication_bookmarks, dependent: :destroy
  has_many :publication_subscriptions, dependent: :destroy
  has_many :content_reports, dependent: :restrict_with_exception

  normalizes :title, with: ->(title) { title.squish }
  normalizes :body, with: ->(body) { body.strip }

  validates :title, presence: true, length: { in: TITLE_LENGTH }, unless: :occurrence?
  validates :body, presence: true, length: { in: BODY_LENGTH }, unless: :occurrence?
  validate :photos_constraints
  validates :alert_id, uniqueness: true, allow_nil: true
  validate :source_rules
  validate :review_consistency
  validate :publication_consistency

  # Alerts que podem alimentar uma publicação, conforme a audiência pedida pelo autor.
  def self.compatible_sources_for(visibility)
    case visibility.to_s
    when "internal"
      Alert.occurrence.where(publication_blocked: false, requested_visibility: %w[internal public_external])
    when "public_external"
      Alert.occurrence.where(publication_blocked: false).where(requested_visibility: "public_external")
    else
      Alert.none
    end
  end

  # Publicações vinculadas cuja fonte mudou depois da aprovação e aguardam revisão editorial.
  scope :needing_source_review, -> { where.not(source_changed_at: nil) }

  def source_compatible?
    return alert_id.nil? unless occurrence?
    return false if alert.nil?

    self.class.compatible_sources_for(visibility).exists?(alert.id)
  end

  def approved_for_current_content?
    review_approved? && reviewed_content_version.present? && reviewed_content_version == content_version
  end

  def expired?(at = Time.current)
    expires_at.present? && expires_at <= at
  end

  private

    def clear_occurrence_copy
      self.author = alert.author if occurrence? && alert && new_record?
      self[:title] = nil if occurrence?
      self[:body] = nil if occurrence?
    end

    def photos_constraints
      return unless photos.attached? || attachment_changes["photos"]

      errors.add(:photos, "devem pertencer ao relato original") if occurrence? && photos.attached?
      errors.add(:photos, :too_many, count: Alert::MAX_PHOTOS) if photos.size > Alert::MAX_PHOTOS
      photos.each do |attachment|
        errors.add(:photos, :content_type) unless Alert::PHOTO_CONTENT_TYPES.include?(attachment.blob.content_type)
        errors.add(:photos, :too_large, megabytes: 5) if attachment.blob.byte_size > Alert::MAX_PHOTO_BYTES
      end
      Alerts::PhotoUpload.validate_pending(self)
    end

    def source_rules
      if occurrence?
        if alert.nil?
          errors.add(:alert, :blank)
        elsif alert.panic?
          errors.add(:alert, :panic_not_publishable)
        elsif !withdrawn? && (new_record? || will_save_change_to_visibility?) && !source_compatible?
          errors.add(:alert, :incompatible_audience)
        end
      elsif alert_id.present?
        errors.add(:alert, :only_for_occurrence)
      end

      errors.add(:alert, :immutable) if persisted? && will_save_change_to_alert_id?
      errors.add(:kind, :immutable) if persisted? && will_save_change_to_kind?
    end

    def review_consistency
      return unless review_approved? || review_rejected?

      errors.add(:reviewed_by, :blank) if reviewed_by.nil? && !approval_verified_author?
      errors.add(:reviewed_at, :blank) if reviewed_at.nil?
      errors.add(:reviewed_content_version, :blank) if reviewed_content_version.nil?
      errors.add(:review_reason, :blank) if review_rejected? && review_reason.blank?
    end

    def publication_consistency
      if published?
        errors.add(:state, :requires_current_approval) unless (occurrence? && internal?) || approved_for_current_content?
        errors.add(:published_at, :blank) if published_at.nil?
        errors.add(:expires_at, :blank) if notice? && expires_at.nil?
      end
      errors.add(:withdrawn_at, :blank) if withdrawn? && withdrawn_at.nil?
      if expires_at.present? && published_at.present? && expires_at <= published_at
        errors.add(:expires_at, :after_publication)
      end
    end
end
