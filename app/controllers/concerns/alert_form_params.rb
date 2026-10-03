# Parâmetros do formulário de ocorrência. Cada modo de localização aceita só os seus campos:
# GPS não leva local do catálogo e seleção manual não leva coordenadas, mesmo que campos
# ocultos tenham ficado preenchidos ao alternar de modo. Autoria, status, prioridade e demais
# campos internos nunca são lidos daqui.
module AlertFormParams
  extend ActiveSupport::Concern

  OCCURRENCE_FIELDS = %i[
    title description category_id category_other_description reported_severity
    location_source location_id latitude longitude location_accuracy_meters location_captured_at
  ].freeze
  GPS_FIELDS = %i[latitude longitude location_accuracy_meters location_captured_at].freeze
  CORRECTION_FIELDS = %i[title description category_id category_other_description].freeze

  private

    def alert_form_params
      params.fetch(:alert, {})
    end

    def occurrence_params(with_visibility: true)
      fields = OCCURRENCE_FIELDS + (with_visibility ? [ :requested_visibility ] : [])
      attributes = alert_form_params.permit(*fields).to_h.symbolize_keys
      attributes.transform_values! { |value| value.is_a?(String) ? value.strip.presence : value }
      normalize_location(attributes)
      normalize_category_details(attributes)
      attributes
    end

    def correction_params
      attributes = alert_form_params.permit(*CORRECTION_FIELDS).to_h.symbolize_keys
      attributes.transform_values! { |value| value.is_a?(String) ? value.strip.presence : value }
      normalize_category_details(attributes)
      attributes
    end

    def normalize_location(attributes)
      case attributes[:location_source]
      when "manual" then GPS_FIELDS.each { |field| attributes[field] = nil }
      when "gps" then attributes[:location_id] = nil
      end
    end

    # O detalhamento só existe para categorias que o exigem ("Outro").
    def normalize_category_details(attributes)
      return unless attributes.key?(:category_id)

      category = Category.find_by(id: attributes[:category_id])
      attributes[:category_other_description] = nil unless category&.requires_details?
    end

    def uploaded_photos
      Array(alert_form_params[:photos]).select { |file| file.respond_to?(:read) }
    end

    def lock_version_param
      params[:lock_version].presence || alert_form_params[:lock_version].presence
    end
end
