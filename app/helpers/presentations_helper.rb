module PresentationsHelper
  def presentation_diagram(key)
    @presentation_diagrams ||= PresentationDiagram.load_all
    @presentation_diagrams.fetch(key)
  end

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

  # Visibilidade --------------------------------------------------------------
  # Tudo é renderizado: o que o perfil desmarca vem com hidden (o modo leitura sem JavaScript
  # e a impressão respeitam o perfil) e o painel temporário pode reexibir no navegador.

  # Bloco configurável de um slide. O id precisa existir em "conteudos" no roteiro.yml.
  def presentation_item(slide, id, tag_name = :div, **options, &block)
    key = slide.item_key(id)
    visible = @selection.item_visible?(key) # levanta erro se a chave não estiver no catálogo
    content_tag(tag_name, **presentation_visibility_options(options, { apr_item: key }, visible), &block)
  end

  # Agrupa blocos configuráveis; fica oculto quando nenhum deles está visível.
  def presentation_group(slide, ids, tag_name = :div, **options, &block)
    visible = ids.map { |id| @selection.item_visible?(slide.item_key(id)) }.any?
    content_tag(tag_name, **presentation_visibility_options(options, { apr_group: "" }, visible), &block)
  end

  # Conteúdo que só faz sentido enquanto o slide referenciado estiver visível (links internos).
  def presentation_slide_ref(slide_id, tag_name = :span, **options, &block)
    visible = @selection.slide_visible?(@presentation.slide(slide_id))
    content_tag(tag_name, **presentation_visibility_options(options, { apr_slide_ref: slide_id }, visible), &block)
  end

  # Alternativa exibida quando o slide referenciado está oculto.
  def presentation_slide_ref_off(slide_id, tag_name = :span, **options, &block)
    visible = !@selection.slide_visible?(@presentation.slide(slide_id))
    content_tag(tag_name, **presentation_visibility_options(options, { apr_slide_ref_off: slide_id }, visible), &block)
  end

  # Número (01) ou letra (A) do slide na sequência visível; o JavaScript recalcula ao filtrar.
  def presentation_slide_label(slide, prefix: nil, **options)
    prefix ||= "Apêndice " if slide.appendix
    data = { apr_label_for: slide.id }
    data[:apr_label_prefix] = prefix if prefix
    tag.span("#{prefix}#{@selection.label(slide) || '—'}", **options, data: data)
  end

  # Texto da estimativa de tempo. A mesma frase é montada em lib/presentation_selection.js.
  def presentation_estimate_text(selection)
    total = selection.total_seconds
    count = selection.visible_main_slides.size
    base = "Estimativa: #{presentation_duration(total)} em #{count} #{count == 1 ? 'slide principal' : 'slides principais'}"
    limit = selection.limit_seconds
    return "#{base} · sem limite de tempo definido para esta entrega." unless limit
    return "#{base} · acima do limite de #{presentation_duration(limit)}." if total > limit

    "#{base} · limite de #{presentation_duration(limit)}."
  end

  # Catálogo enviado ao JavaScript (página pública e admin). Mesma origem: roteiro.yml.
  def presentation_catalog_data(presentation)
    presentation.slides.map do |slide|
      {
        id: slide.id, title: slide.title, appendix: slide.appendix, required: slide.required,
        seconds: slide.seconds, default: slide.default,
        items: slide.items.map { |item| { key: item.key, title: item.title, default: item.default, parent: item.parent_key } }
      }
    end
  end

  private

    def presentation_visibility_options(options, data, visible)
      options.merge(data: (options[:data] || {}).merge(data), hidden: (true unless visible))
    end
end
