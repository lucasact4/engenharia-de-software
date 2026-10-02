# Trilha de auditoria append-only na API da aplicação.

class AuditEvent < ApplicationRecord
  SUBJECT_TYPES = %w[Alert Publication Comment ContentReport User].freeze

  ALLOWED_CHANGES = {
    "Alert" => %w[status priority assessed_severity assigned_to_id visibility requested_visibility
                  closure_reason duplicate_of_id resolved_at closed_at],
    "Publication" => %w[state review_status visibility content_version reviewed_content_version
                        expires_at comments_enabled published_at withdrawn_at source_changed_at],
    "Comment" => %w[removed_at removed_by_id],
    "ContentReport" => %w[state],
    "User" => %w[deleted_at]
  }.freeze

  METADATA_KEYS = %w[kind fields role_code decision target_type source reopening system_reason
                     protocol idempotent_replay photos_count].freeze
  MAX_STRING = 200

  belongs_to :actor, class_name: "User", optional: true
  belongs_to :subject, polymorphic: true

  validates :action, presence: true, length: { in: 3..80 }
  validates :subject_type, inclusion: { in: SUBJECT_TYPES }
  validates :reason, length: { maximum: 1000 }
  validates :actor, presence: true, unless: -> { action.to_s.start_with?("system.") }

  before_update { raise ActiveRecord::ReadOnlyRecord, "audit_events é append-only" }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "audit_events é append-only" }

  scope :for_subject, ->(subject) { where(subject_type: subject.class.name, subject_id: subject.id) }

  def readonly?
    persisted? || super
  end

  # changes: { "status" => [antes, depois] }.
  def self.record!(actor:, action:, subject:, changes: {}, reason: nil, metadata: {})
    allowed = ALLOWED_CHANGES.fetch(subject.class.name, [])
    create!(
      actor: actor,
      action: action,
      subject: subject,
      reason: reason.to_s.strip.presence&.truncate(1000),
      changeset: changes.to_h.stringify_keys.slice(*allowed).transform_values { |pair| Array(pair).map { |v| scalar(v) } },
      metadata: metadata.to_h.stringify_keys.slice(*METADATA_KEYS).transform_values { |value| sanitize_value(value) }
    )
  end

  def self.sanitize_value(value)
    value.is_a?(Array) ? value.first(20).map { |item| scalar(item) } : scalar(value)
  end

  def self.scalar(value)
    case value
    when nil, true, false, Integer then value
    when Time, ActiveSupport::TimeWithZone, Date then value.iso8601
    else value.to_s.truncate(MAX_STRING)
    end
  end
  private_class_method :sanitize_value, :scalar
end
