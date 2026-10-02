module Alerts
  # Registra pânico mesmo sem GPS ou texto. Recebimento no sistema não confirma atendimento humano.
  class CreatePanic < Create
    PERMITTED = %i[
      title description location_source location_id latitude longitude
      location_accuracy_meters location_captured_at location_unavailable_reason reported_severity
    ].freeze

    private

      def policy_query = :create_panic?
      def kind = "panic"
      def client_request_required? = true

      def alert_attributes
        attributes = @attributes.dup
        attributes[:location_source] = inferred_location_source(attributes) if attributes[:location_source].blank?
        if attributes[:location_source].to_s == "unavailable"
          attributes[:location_unavailable_reason] = attributes[:location_unavailable_reason].presence || "not_shared"
        end

        attributes.merge(kind: kind, requested_visibility: "restricted", visibility: "restricted")
      end

      def inferred_location_source(attributes)
        if attributes[:latitude].present? || attributes[:longitude].present?
          "gps"
        elsif attributes[:location_id].present?
          "manual"
        else
          "unavailable"
        end
      end
  end
end
