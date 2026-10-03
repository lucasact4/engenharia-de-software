# Filtros e ordenação das listas de alertas (fila de atendimento e admin). Sempre aplicados
# sobre um scope já autorizado; colunas e direções vêm de allowlists.
module AlertQueueFilters
  extend ActiveSupport::Concern

  SORTS = {
    "recentes" => "alerts.created_at DESC, alerts.id DESC",
    "antigos" => "alerts.created_at ASC, alerts.id ASC",
    "prioridade" => "CASE alerts.priority WHEN 'urgent' THEN 0 WHEN 'high' THEN 1 WHEN 'normal' THEN 2 " \
                    "WHEN 'low' THEN 3 ELSE 4 END, alerts.created_at ASC",
    "situacao" => "CASE alerts.status WHEN 'received' THEN 0 WHEN 'triaging' THEN 1 WHEN 'awaiting_information' THEN 2 " \
                  "WHEN 'in_progress' THEN 3 WHEN 'resolved' THEN 4 ELSE 5 END, alerts.created_at ASC"
  }.freeze
  OPEN_STATUSES = %w[received triaging in_progress awaiting_information].freeze

  private

    def apply_queue_filters(scope, default_open: false)
      filters = queue_filter_params
      scope = filter_term(scope, filters[:q])
      scope = scope.where(kind: filters[:kind]) if Alert.kinds.key?(filters[:kind].to_s)
      scope = filter_status(scope, filters[:status], default_open)
      scope = filter_priority(scope, filters[:priority])
      scope = scope.where(category_id: filters[:category_id]) if filters[:category_id].present?
      scope = scope.where(location_id: filters[:location_id]) if filters[:location_id].present?
      scope = scope.where(requested_visibility: filters[:visibility]) if Alert.requested_visibilities.key?(filters[:visibility].to_s)
      scope = filter_assignee(scope, filters[:assigned])
      scope = filter_period(scope, filters[:from], filters[:to])
      scope.reorder(Arel.sql(SORTS.fetch(filters[:sort].to_s, SORTS["recentes"])))
    end

    def queue_filter_params
      params.permit(:q, :kind, :status, :priority, :category_id, :location_id, :visibility, :assigned, :from, :to, :sort)
    end

    def filter_term(scope, term)
      scope.text_search(term, "alerts.protocol", "alerts.title")
    end

    def filter_status(scope, status, default_open)
      return scope.where(status: status) if Alert.statuses.key?(status.to_s)
      return scope if status == "todas" || !default_open && status.blank?

      scope.where(status: OPEN_STATUSES)
    end

    # "Ainda não classificada" é diferente de prioridade baixa.
    def filter_priority(scope, priority)
      return scope.where(priority: nil) if priority == "unclassified"
      return scope.where(priority: priority) if Alert.priorities.key?(priority.to_s)

      scope
    end

    def filter_assignee(scope, assigned)
      case assigned.to_s
      when "" then scope
      when "me" then scope.where(assigned_to_id: Current.user.id)
      when "none" then scope.where(assigned_to_id: nil)
      else scope.where(assigned_to_id: assigned.to_i)
      end
    end

    def filter_period(scope, from, to)
      from_date = Date.iso8601(from.to_s) rescue nil
      to_date = Date.iso8601(to.to_s) rescue nil
      scope = scope.where(alerts: { created_at: from_date.in_time_zone.. }) if from_date
      scope = scope.where(alerts: { created_at: ..to_date.in_time_zone.end_of_day }) if to_date
      scope
    end

    # Filtros aceitam entradas inativas: o histórico continua consultável.
    def catalog_filter_options(model)
      model.ordered.map do |entry|
        label = entry.active? ? entry.name : "#{entry.name} (inativo)"
        SelectOption.new(value: entry.id, label: label, description: nil, disabled: false)
      end
    end

    def queue_filter_options
      presenter = AlertOptionsPresenter.new(actor: Current.user)
      {
        kinds: presenter.kinds,
        statuses: presenter.statuses,
        priorities: [ SelectOption.new(value: "unclassified", label: "Ainda não classificada", description: nil, disabled: false) ] +
          Alert.priorities.values.map { |value| SelectOption.from_enum("alert.priority", value) },
        categories: catalog_filter_options(Category),
        locations: catalog_filter_options(Location),
        visibilities: presenter.requested_visibilities(kind: "occurrence")
      }
    end
end
