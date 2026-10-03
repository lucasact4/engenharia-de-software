# Registro de ocorrência ou pânico; a divulgação editorial fica em Publication.
class Alert < ApplicationRecord
  include TextSearch
  TITLE_LENGTH = 5..160
  DESCRIPTION_LENGTH = 10..5000
  CATEGORY_DETAILS_MAX = 500
  MAX_PHOTOS = 5
  MAX_PHOTO_BYTES = 5 * 1024 * 1024
  PHOTO_CONTENT_TYPES = %w[image/png image/jpeg].freeze
  # Metadados do GPS vêm do navegador: limites de coerência, não prova de local.
  MAX_ACCURACY_METERS = 100_000
  CAPTURE_CLOCK_SKEW = 5.minutes
  CAPTURE_MAX_AGE = 24.hours

  SEVERITIES = { low: "low", moderate: "moderate", high: "high", critical: "critical" }.freeze

  # Matriz provisória de atendimento. Não é obrigatório passar por todos os estados.
  TRANSITIONS = {
    "received" => %w[triaging closed],
    "triaging" => %w[in_progress awaiting_information closed],
    "in_progress" => %w[awaiting_information resolved closed],
    "awaiting_information" => %w[triaging in_progress closed],
    "resolved" => %w[closed in_progress],
    "closed" => %w[triaging]
  }.freeze

  # Reaberturas exigem motivo; reabrir um alerta encerrado é exclusivo da administração.
  REOPENINGS = { "resolved" => "in_progress", "closed" => "triaging" }.freeze
  CLOSURE_REASONS_REQUIRING_NOTES = %w[invalid out_of_scope other].freeze

  enum :kind, { occurrence: "occurrence", panic: "panic" }, validate: true
  enum :location_source, { gps: "gps", manual: "manual", unavailable: "unavailable" },
       prefix: :location, validate: true
  enum :location_unavailable_reason,
       { permission_denied: "permission_denied", position_unavailable: "position_unavailable",
         timeout: "timeout", not_supported: "not_supported", not_shared: "not_shared" },
       prefix: :unavailable, validate: { allow_nil: true }
  enum :requested_visibility,
       { internal: "internal", restricted: "restricted", public_external: "public_external" },
       prefix: :requested, validate: true
  enum :visibility, { internal: "internal", restricted: "restricted" }, prefix: :visibility, validate: true
  enum :reported_severity, SEVERITIES, prefix: :reported, validate: { allow_nil: true }
  enum :assessed_severity, SEVERITIES, prefix: :assessed, validate: { allow_nil: true }
  enum :priority, { low: "low", normal: "normal", high: "high", urgent: "urgent" },
       prefix: :priority, validate: { allow_nil: true }
  enum :status,
       { received: "received", triaging: "triaging", in_progress: "in_progress",
         awaiting_information: "awaiting_information", resolved: "resolved", closed: "closed" },
       validate: true
  enum :closure_reason,
       { resolved: "resolved", duplicate: "duplicate", invalid: "invalid",
         out_of_scope: "out_of_scope", other: "other" },
       prefix: :closure, validate: { allow_nil: true }

  belongs_to :author, class_name: "User", inverse_of: :authored_alerts
  belongs_to :category, optional: true
  belongs_to :location, optional: true
  belongs_to :assigned_to, class_name: "User", optional: true, inverse_of: :assigned_alerts
  belongs_to :duplicate_of, class_name: "Alert", optional: true

  has_one :publication, dependent: :restrict_with_exception
  has_many :duplicates, class_name: "Alert", foreign_key: :duplicate_of_id, inverse_of: :duplicate_of,
           dependent: :restrict_with_exception
  has_many :alert_subscriptions, dependent: :destroy
  has_many_attached :photos

  before_validation :assign_protocol, on: :create

  validates :protocol, presence: true, uniqueness: true
  validates :title, length: { maximum: TITLE_LENGTH.max }
  validates :description, length: { maximum: DESCRIPTION_LENGTH.max }
  validates :category_other_description, length: { maximum: CATEGORY_DETAILS_MAX }
  validates :latitude, numericality: { in: -90..90 }, allow_nil: true
  validates :longitude, numericality: { in: -180..180 }, allow_nil: true
  validates :location_accuracy_meters,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_ACCURACY_METERS }, allow_nil: true
  validates :client_request_id, length: { in: 8..64 }, allow_nil: true

  with_options if: :occurrence? do
    validates :title, presence: true, length: { in: TITLE_LENGTH }
    validates :description, presence: true, length: { in: DESCRIPTION_LENGTH }
    validates :category, presence: true
  end

  validate :occurrence_location_available
  validate :category_details
  validate :active_catalog_entries
  validate :location_consistency
  validate :gps_capture_time
  validate :visibility_consistency
  validate :panic_rules
  validate :closure_consistency
  validate :duplicate_reference
  validate :assignee_active
  validate :photos_constraints

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  def self.allowed_transitions_from(status)
    TRANSITIONS.fetch(status.to_s, [])
  end

  def transition_allowed?(target)
    self.class.allowed_transitions_from(status).include?(target.to_s)
  end

  def reopening?(target)
    REOPENINGS[status] == target.to_s
  end

  private

    def assign_protocol
      self.protocol ||= Alerts::Protocol.generate
    end

    def occurrence_location_available
      errors.add(:location_source, :required_for_occurrence) if occurrence? && location_unavailable?
    end

    # Só vale ao escolher a categoria ou editar o detalhe: mudanças posteriores no catálogo
    # não podem impedir o atendimento de registros antigos.
    def category_details
      return unless category&.requires_details?
      return unless new_record? || will_save_change_to_category_id? || will_save_change_to_category_other_description?
      return if category_other_description.present?

      errors.add(:category_other_description, :blank)
    end

    # Itens inativos permanecem válidos no histórico, mas não para uma nova associação.
    def active_catalog_entries
      errors.add(:category, :inactive) if category && will_save_change_to_category_id? && !category.active?
      errors.add(:location, :inactive) if location && will_save_change_to_location_id? && !location.active?
    end

    def location_consistency
      if latitude.nil? != longitude.nil?
        errors.add(:base, :coordinates_pair)
      end

      case location_source
      when "gps"
        errors.add(:base, :gps_coordinates_required) if latitude.nil? || longitude.nil?
      when "manual"
        errors.add(:location, :blank) if location.nil?
        errors.add(:base, :manual_without_coordinates) if latitude.present? || longitude.present?
      when "unavailable"
        errors.add(:base, :unavailable_without_location) if location.present? || latitude.present?
      end

      unless location_gps?
        errors.add(:location_accuracy_meters, :gps_only) if location_accuracy_meters.present?
        errors.add(:location_captured_at, :gps_only) if location_captured_at.present?
      end
      errors.add(:location_unavailable_reason, :unavailable_only) if location_unavailable_reason.present? && !location_unavailable?
    end

    def gps_capture_time
      raw = location_captured_at_before_type_cast
      if raw.present? && location_captured_at.nil?
        errors.add(:location_captured_at, :invalid)
        return
      end
      return unless location_captured_at && will_save_change_to_location_captured_at?

      now = Time.current
      errors.add(:location_captured_at, :in_future) if location_captured_at > now + CAPTURE_CLOCK_SKEW
      errors.add(:location_captured_at, :too_old) if location_captured_at < now - CAPTURE_MAX_AGE
    end

    # O registro operacional nunca é público. Pedido de divulgação externa mantém o
    # registro restrito até existir uma Publication revisada.
    def visibility_consistency
      return if visibility.nil? || requested_visibility.nil?

      errors.add(:visibility, :must_match_request) if visibility_internal? && !requested_internal?
    end

    def panic_rules
      return unless panic?

      errors.add(:requested_visibility, :panic_restricted) unless requested_restricted?
      errors.add(:visibility, :panic_restricted) unless visibility_restricted?
      errors.add(:client_request_id, :blank) if client_request_id.blank?
    end

    def closure_consistency
      if closed?
        errors.add(:closure_reason, :blank) if closure_reason.blank?
        errors.add(:closed_at, :blank) if closed_at.blank?
        if CLOSURE_REASONS_REQUIRING_NOTES.include?(closure_reason) && closure_notes.blank?
          errors.add(:closure_notes, :blank)
        end
      else
        errors.add(:closure_reason, :only_when_closed) if closure_reason.present?
        errors.add(:closed_at, :only_when_closed) if closed_at.present?
      end

      errors.add(:resolved_at, :blank) if resolved? && resolved_at.blank?
      errors.add(:resolved_at, :only_when_resolved) if resolved_at.present? && !(resolved? || closed?)
    end

    def duplicate_reference
      if closure_duplicate? && duplicate_of.nil?
        errors.add(:duplicate_of, :blank)
      end
      return if duplicate_of.nil?

      errors.add(:duplicate_of, :only_for_duplicate) unless closure_duplicate?
      errors.add(:duplicate_of, :self_reference) if duplicate_of_id == id && id.present?
      errors.add(:duplicate_of, :cycle) if duplicate_cycle?
    end

    def duplicate_cycle?
      seen = Set[id]
      current = duplicate_of
      while current
        return true if seen.include?(current.id)

        seen << current.id
        current = current.duplicate_of
      end
      false
    end

    def assignee_active
      return unless assigned_to && will_save_change_to_assigned_to_id?

      errors.add(:assigned_to, :inactive) unless assigned_to.active?
    end

    def photos_constraints
      return unless photos.attached? || attachment_changes["photos"]

      blobs = photos.map(&:blob)
      errors.add(:photos, :too_many, count: MAX_PHOTOS) if blobs.size > MAX_PHOTOS
      blobs.each do |blob|
        errors.add(:photos, :content_type) unless PHOTO_CONTENT_TYPES.include?(blob.content_type)
        errors.add(:photos, :too_large, megabytes: MAX_PHOTO_BYTES / 1.megabyte) if blob.byte_size.to_i > MAX_PHOTO_BYTES
      end
      Alerts::PhotoUpload.validate_pending(self)
    end
end
