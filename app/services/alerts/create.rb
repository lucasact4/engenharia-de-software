module Alerts
  # Criação com idempotência por autor e UUID; reutilizar a chave com outro conteúdo gera conflito.
  class Create < ApplicationService
    UUID_FORMAT = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/
    PROTOCOL_ATTEMPTS = 3
    NUMERIC_ATTRIBUTES = %i[category_id location_id latitude longitude location_accuracy_meters].freeze

    Result = Data.define(:alert, :created) do
      def created? = created
    end

    class IdempotencyConflict < StandardError; end

    attr_reader :actor

    def initialize(actor:, attributes: {}, photos: [], client_request_id: nil)
      @actor = actor
      @attributes = attributes.to_h.symbolize_keys.slice(*self.class::PERMITTED)
      @photos = Array(photos).compact_blank
      @client_request_id = client_request_id.to_s.strip.downcase.presence
    end

    def call
      authorize!(Alert, policy_query)
      validate_client_request_id!
      digest = request_digest

      existing = find_existing
      return replay(existing, digest) if existing

      attempts = 0
      begin
        attempts += 1
        alert = build_alert(digest)
        persist!(alert)
        Result.new(alert: alert, created: true)
      rescue ActiveRecord::RecordNotUnique
        existing = find_existing
        return replay(existing, digest) if existing
        retry if attempts < PROTOCOL_ATTEMPTS

        raise
      end
    end

    private

      def build_alert(digest)
        alert = Alert.new(alert_attributes)
        alert.author = actor
        alert.client_request_id = @client_request_id
        alert.client_request_digest = digest if @client_request_id
        alert.photos.attach(@photos) if @photos.any?
        alert
      end

      def persist!(alert)
        Alert.transaction do
          alert.save!
          AuditEvent.record!(
            actor: actor, action: "alert.created", subject: alert,
            metadata: { kind: alert.kind, photos_count: @photos.size }
          )
          after_persist(alert)
        end
      end

      def after_persist(_alert); end

      def find_existing
        return if @client_request_id.nil?

        Alert.find_by(author_id: actor.id, client_request_id: @client_request_id)
      end

      def replay(existing, digest)
        raise IdempotencyConflict, "client_request_id já usado com outro conteúdo" if existing.client_request_digest != digest

        Result.new(alert: existing, created: false)
      end

      def validate_client_request_id!
        return if @client_request_id.nil? && !client_request_required?
        return if @client_request_id.to_s.match?(UUID_FORMAT)

        alert = Alert.new
        alert.errors.add(:client_request_id, :invalid)
        raise ActiveRecord::RecordInvalid, alert
      end

      def client_request_required?
        false
      end

      # Resumo canônico do pedido: atributos normalizados e SHA-256 do conteúdo das fotos.
      def request_digest
        payload = @attributes.to_h { |key, value| [ key, canonical(key, value) ] }.sort.to_h
        payload[:kind] = kind
        payload[:photos] = @photos.map { |photo| photo_digest(photo) }
        Digest::SHA256.hexdigest(payload.to_json)
      end

      def canonical(key, value)
        return nil if value.nil?
        return value.utc.iso8601 if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone) || value.is_a?(DateTime)

        string = value.to_s.strip
        if NUMERIC_ATTRIBUTES.include?(key) && string.match?(/\A-?\d+(\.\d+)?\z/)
          BigDecimal(string).round(7).to_s("F")
        else
          string
        end
      end

      def photo_digest(photo)
        io = PhotoUpload.io_for(photo)
        return Digest::SHA256.hexdigest(photo.to_s) unless io.respond_to?(:read)

        io.rewind if io.respond_to?(:rewind)
        digest = Digest::SHA256.new
        while (chunk = io.read(64.kilobytes))
          digest << chunk
        end
        io.rewind if io.respond_to?(:rewind)
        digest.hexdigest
      end
  end
end
