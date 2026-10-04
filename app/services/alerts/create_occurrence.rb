module Alerts
  # Registro e post são criados na mesma transação; a divulgação externa segue a regra do selo.
  class CreateOccurrence < Create
    PERMITTED = %i[
      title description category_id category_other_description
      location_source location_id location_description latitude longitude location_accuracy_meters location_captured_at
      requested_visibility reported_severity
    ].freeze

    private

      def policy_query = :create_occurrence?
      def kind = "occurrence"

      def after_persist(alert)
        Publications::SyncOccurrence.call(actor: actor, alert: alert, request_external: true)
      end

      def alert_attributes
        @attributes[:requested_visibility] ||= "internal"
        @attributes[:title] = Alert.title_from(@attributes[:description]) unless @attributes.key?(:title)
        @attributes.merge(
          kind: kind,
          visibility: @attributes[:requested_visibility].to_s == "internal" ? "internal" : "restricted"
        )
      end
  end
end
