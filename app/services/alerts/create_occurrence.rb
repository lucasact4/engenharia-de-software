module Alerts
  # Registra uma ocorrência; pedido de divulgação externa ainda exige revisão editorial.
  class CreateOccurrence < Create
    PERMITTED = %i[
      title description category_id category_other_description
      location_source location_id latitude longitude location_accuracy_meters location_captured_at
      requested_visibility reported_severity
    ].freeze

    private

      def policy_query = :create_occurrence?
      def kind = "occurrence"

      def alert_attributes
        @attributes.merge(
          kind: kind,
          visibility: @attributes[:requested_visibility].to_s == "internal" ? "internal" : "restricted"
        )
      end
  end
end
