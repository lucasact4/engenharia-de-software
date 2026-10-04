# Marca do SGU (arquivos em app/assets/images/brand/, gerados por script/gerar_marca_sgu.rb).
#
# layout: :symbol (só o escudo), :horizontal (escudo + SGU ao lado) ou :vertical (SGU abaixo).
# tone:   :auto acompanha o tema da página (versão padrão no claro, negativa no escuro);
#         :on_light e :on_dark fixam a versão quando o fundo não muda com o tema;
#         :dark_surface usa a negativa na tela e a padrão na impressão (slides escuros ficam claros no PDF).
module BrandHelper
  BRAND_FILES = { symbol: "simbolo", horizontal: "logo-horizontal", vertical: "logo-vertical" }.freeze
  BRAND_TONES = %i[auto on_light on_dark dark_surface].freeze

  def sgu_brand(layout = :horizontal, tone: :auto, alt: "SGU", class_name: nil)
    file = BRAND_FILES.fetch(layout)
    raise ArgumentError, "Tom de marca desconhecido: #{tone.inspect}" unless BRAND_TONES.include?(tone)

    css = [ "sgu-brand", "sgu-brand--#{layout}", class_name ]
    return image_tag(brand_path(file, tone), alt: alt, class: css, decoding: "async") if %i[on_light on_dark].include?(tone)

    # As duas versões ficam no HTML; o CSS de theme.css mostra apenas a adequada ao fundo.
    attributes = alt.present? ? { role: "img", aria: { label: alt } } : { aria: { hidden: true } }
    tag.span(class: [ *css, "sgu-brand--#{tone.to_s.dasherize}" ], **attributes) do
      safe_join([
        image_tag(brand_path(file, :on_light), alt: "", class: "sgu-brand__on-light", decoding: "async"),
        image_tag(brand_path(file, :on_dark), alt: "", class: "sgu-brand__on-dark", decoding: "async")
      ])
    end
  end

  private

    def brand_path(file, tone)
      "brand/sgu-#{file}#{'-negativo' if tone == :on_dark}.svg"
    end
end
