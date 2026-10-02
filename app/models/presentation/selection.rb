# Resolve o que aparece na apresentação a partir das escolhas de um perfil.
#
# Regras (espelhadas em app/javascript/controllers/presentation_controller.js):
# - chave sem escolha salva usa o "padrao" do roteiro.yml (perfis antigos continuam válidos
#   quando o catálogo ganha slides ou conteúdos);
# - capa e encerramento são sempre visíveis;
# - um conteúdo com "dentro_de" só aparece se o conteúdo pai aparecer;
# - um slide marcado cujos conteúdos foram todos desmarcados é omitido da sequência,
#   para não exibir uma tela só com o título;
# - números (01, 02…) e letras dos apêndices são recalculados sobre os slides visíveis.
class Presentation::Selection
  attr_reader :presentation, :profile_name

  def initialize(presentation, choices = {}, delivery_id: nil, profile_name: nil)
    @presentation = presentation
    @choices = (choices || {}).to_h.transform_keys(&:to_s).select do |key, value|
      presentation.catalog_key?(key) && [ true, false ].include?(value)
    end
    @delivery = presentation.delivery(delivery_id) || presentation.default_delivery
    @profile_name = profile_name
  end

  def delivery = @delivery

  # Valor marcado no checkbox (antes das regras de dependência).
  def chosen?(key)
    key = key.to_s
    slide = presentation.slide(key)
    return true if slide&.required
    return @choices[key] if @choices.key?(key)

    (slide || presentation.item(key)).default
  end

  def item_visible?(key)
    item = presentation.item(key.to_s) or raise ArgumentError, "Conteúdo fora do catálogo: #{key}"
    chosen?(item.key) && (item.parent_key.nil? || item_visible?(item.parent_key))
  end

  def slide_visible?(slide)
    slide = presentation.slide(slide) if slide.is_a?(String)
    return true if slide.required
    return false unless chosen?(slide.id)

    slide.items.empty? || slide.items.any? { |item| item_visible?(item.key) }
  end

  # Marcado, mas sem nenhum conteúdo visível: será omitido.
  def without_content?(slide)
    !slide.required && chosen?(slide.id) && slide.items.any? && !slide_visible?(slide)
  end

  def visible_slides = presentation.slides.select { |slide| slide_visible?(slide) }
  def visible_main_slides = visible_slides.reject(&:appendix)
  def visible_appendix_slides = visible_slides.select(&:appendix)

  def label(slide)
    labels[slide.id]
  end

  def total_seconds
    visible_main_slides.sum(&:seconds)
  end

  def limit_seconds
    minutes = delivery[:duracao_maxima_minutos]
    minutes * 60 if minutes
  end

  def over_limit?
    limit_seconds.present? && total_seconds > limit_seconds
  end

  # Escolhas efetivas de todas as chaves do catálogo (estado inicial dos checkboxes).
  def to_h
    presentation.catalog_keys.index_with { |key| chosen?(key) }
  end

  private

    def labels
      @labels ||= begin
        main = visible_main_slides.each_with_index.to_h { |slide, index| [ slide.id, format("%02d", index + 1) ] }
        letters = visible_appendix_slides.zip("A".."Z").to_h { |slide, letter| [ slide.id, letter ] }
        main.merge(letters)
      end
    end
end
