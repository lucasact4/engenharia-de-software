module PresentationsHelper
  STATE_ICONS = {
    "implementado" => "✓",
    "parcial" => "", # meio círculo desenhado em CSS
    "planejado" => "", # círculo vazado desenhado em CSS
    "aguardando_decisao" => "?",
    "aguardando_evidencia" => "…"
  }.freeze

  def presentation_state(state, short: false)
    state = state.to_s
    label = Presentation::STATES.fetch(state) { raise ArgumentError, "Estado desconhecido na apresentação: #{state.inspect}" }
    label = "Parcial" if short && state == "parcial"

    tag.span(class: "apr-state apr-state--#{state.dasherize}") do
      safe_join([ tag.span(STATE_ICONS.fetch(state), class: "apr-state__icon", aria: { hidden: true }), label ])
    end
  end

  # Só URLs públicas viram link; caminhos locais (C:\, \\wsl, /mnt, file:) aparecem como texto.
  def presentation_link(label, url, **options)
    return tag.span(label, class: options[:class]) unless url.to_s.match?(%r{\Ahttps?://}i)

    link_to url, class: options[:class], target: "_blank", rel: "noopener noreferrer" do
      safe_join([ label, tag.span(" (abre em nova aba)", class: "apr-sr-only") ])
    end
  end

  def presentation_commit_link(sha)
    return if sha.blank?

    url = "#{@presentation.entrega.dig(:links, :github)}/commit/#{sha}"
    presentation_link(sha.first(7), url, class: "apr-code apr-code--link")
  end

  def presentation_path(path)
    tag.code(path, class: "apr-code") if path.present?
  end

  def presentation_duration(seconds)
    minutes, rest = seconds.divmod(60)
    return "#{rest}s" if minutes.zero?

    rest.zero? ? "#{minutes}min" : "#{minutes}min#{rest.to_s.rjust(2, '0')}s"
  end

  def presentation_date(date)
    date.to_date.strftime("%d/%m/%Y") if date.present?
  end

  # Nota visível só no modo leitura: indica à equipe onde atualizar o conteúdo.
  def presentation_update_note(file, text = nil)
    tag.p(class: "apr-maint") do
      safe_join([ tag.strong("Atualizar: "), tag.code("config/presentation/#{file}"), (" — #{text}" if text) ].compact)
    end
  end
end
