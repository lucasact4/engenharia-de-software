# Auxiliares visuais do portal e das telas de domínio. Rótulos vêm do I18n/presenters;
# nenhuma regra de acesso é decidida aqui.
module PortalHelper
  STATUS_BADGES = {
    "received" => "sky", "triaging" => "amber", "in_progress" => "violet",
    "awaiting_information" => "amber", "resolved" => "green", "closed" => "slate"
  }.freeze
  PRIORITY_BADGES = { "low" => "slate", "normal" => "sky", "high" => "amber", "urgent" => "red" }.freeze
  SEVERITY_BADGES = { "low" => "slate", "moderate" => "sky", "high" => "amber", "critical" => "red" }.freeze
  PUBLICATION_STATE_BADGES = { "draft" => "slate", "published" => "green", "withdrawn" => "red" }.freeze
  REVIEW_BADGES = { "not_submitted" => "slate", "pending" => "amber", "approved" => "teal", "rejected" => "red" }.freeze
  REPORT_STATE_BADGES = { "pending" => "amber", "actioned" => "green", "dismissed" => "slate" }.freeze

  def sgu_icon(name, css = "size-4")
    icon(name, class: "#{css} shrink-0", "aria-hidden": "true")
  end

  def enum_label(scope, value)
    return if value.blank?

    t("enums.#{scope}.#{value}.label")
  end

  def enum_description(scope, value)
    return if value.blank?

    t("enums.#{scope}.#{value}.description")
  end

  def enum_badge(scope, value, palette, empty: nil)
    return tag.span(empty, class: "sgu-badge sgu-badge-slate") if value.blank? && empty

    tag.span(enum_label(scope, value), class: "sgu-badge sgu-badge-#{palette.fetch(value.to_s, 'slate')}",
                                       title: enum_description(scope, value))
  end

  def alert_status_badge(alert)
    enum_badge("alert.status", alert.status, STATUS_BADGES)
  end

  # "Ainda não classificado" é diferente de prioridade baixa.
  def alert_priority_badge(alert)
    enum_badge("alert.priority", alert.priority, PRIORITY_BADGES, empty: "Ainda não classificada")
  end

  def alert_severity_badge(value, empty: "Não informada")
    enum_badge("alert.severity", value, SEVERITY_BADGES, empty: empty)
  end

  def sgu_time(time, format: "%d/%m/%Y às %H:%M")
    return "—" if time.blank?

    time = Time.zone.parse(time) if time.is_a?(String)
    tag.time(time.in_time_zone.strftime(format), datetime: time.iso8601)
  end

  # Mensagens do campo, ligadas ao input por aria-describedby.
  def field_errors(record, attribute, id: nil)
    messages = record.errors.messages_for(attribute)
    return if messages.empty?

    tag.p(messages.to_sentence, class: "sgu-field-error", id: id)
  end

  def invalid?(record, *attributes)
    attributes.any? { |attribute| record.errors.include?(attribute) }
  end

  def options_from_select_options(options, selected = nil, include_blank: nil)
    choices = options.map do |option|
      option = option.to_h
      label = option[:disabled] ? "#{option[:label]} (indisponível)" : option[:label]
      [ label, option[:value], { disabled: option[:disabled], title: option[:description] } ]
    end
    choices.unshift([ include_blank, "" ]) if include_blank
    options_for_select(choices, selected.to_s)
  end

  def nav_link(label, path, icon_name, active: current_page?(path))
    link_to path, class: "sgu-nav-link", aria: { current: (active ? "page" : nil) } do
      safe_join([ sgu_icon(icon_name), tag.span(label) ])
    end
  end

  def handling_queue_available?
    Current.user.present? && AlertPolicy.new(Current.user, Alert).queue?
  end

  def initials_for(name)
    name.to_s.split.first(2).map { |part| part[0] }.join.upcase.presence || "?"
  end

  def excerpt(text, length: 220)
    truncate(text.to_s.squish, length: length, separator: " ")
  end
end
