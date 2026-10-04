# Gera a marca do SGU: SVGs (fonte vetorial) e PNGs com fundo transparente.
#
# Uso, na raiz do projeto:
#   bundle exec ruby script/gerar_marca_sgu.rb
#
# A geometria do símbolo e das letras "SGU" fica neste arquivo; todos os arquivos de
# app/assets/images/brand/ e os ícones de public/ são regenerados a partir dela.
# As letras são desenhadas como traços geométricos (sem fonte externa nem licença de terceiros).
require "fileutils"
require "vips"

ROOT = File.expand_path("..", __dir__)
BRAND_DIR = File.join(ROOT, "app/assets/images/brand")

# Paleta do sistema (app/assets/stylesheets/theme.css). O dourado é o acento já usado na interface.
TONES = {
  # Para fundos claros.
  "padrao" => { shield: "#153C36", field: "#226A5C", sprout: "#F4F7F5", seed: "#F2BD57", text: "#153C36" },
  # Para fundos escuros: escudo mais claro para manter o contorno visível.
  "negativo" => { shield: "#226A5C", field: "#2F8A76", sprout: "#F4F7F5", seed: "#F2BD57", text: "#EDF5F3" }
}.freeze

SYMBOL_BOX = [ 0, 0, 100, 112 ].freeze # x, y, largura, altura
SHIELD = "M14 6H86A10 10 0 0 1 96 16V54C96 81 77 98 50 108C23 98 4 81 4 54V16A10 10 0 0 1 14 6Z"
FIELD = "M4 79C18 71 34 67 50 67S82 71 96 79V54 120H4Z"
STEM = "M50 86V50"
LEAF_LEFT = "M50 66C46 54 37 47 25 46C27 58 36 66 50 66Z"
LEAF_RIGHT = "M50 56C55 42 66 34 80 33C78 48 66 56 50 56Z"
SEED = [ 50, 33, 6.5 ].freeze

# Letras com traço de 18 unidades e altura de 100 (as curvas ultrapassam 2 unidades).
WORD_STROKE = 18
WORD_WIDTH = 259
WORD_LETTERS = [
  "M57 9H32.5A20.5 20.5 0 0 0 32.5 50A20.5 20.5 0 0 1 32.5 91H5", # S
  "M155.21 21.9A42 42 0 1 0 166 50H130", # G
  "M196 0V65A27 27 0 0 0 250 65V0" # U
].freeze

def symbol_group(tone, id = tone)
  colors = TONES.fetch(tone)
  <<~SVG.strip
    <g id="simbolo-#{id}">
      <defs><clipPath id="escudo-#{id}"><path d="#{SHIELD}"/></clipPath></defs>
      <path d="#{SHIELD}" fill="#{colors[:shield]}"/>
      <path d="#{FIELD}" fill="#{colors[:field]}" clip-path="url(#escudo-#{id})"/>
      <path d="#{STEM}" fill="none" stroke="#{colors[:sprout]}" stroke-width="7" stroke-linecap="round"/>
      <path d="#{LEAF_LEFT}" fill="#{colors[:sprout]}"/>
      <path d="#{LEAF_RIGHT}" fill="#{colors[:sprout]}"/>
      <circle cx="#{SEED[0]}" cy="#{SEED[1]}" r="#{SEED[2]}" fill="#{colors[:seed]}"/>
    </g>
  SVG
end

def word_group(tone, x:, y:, scale:, id: tone)
  color = TONES.fetch(tone)[:text]
  paths = WORD_LETTERS.map { |d| %(<path d="#{d}"/>) }.join
  %(<g id="letras-sgu-#{id}" transform="translate(#{x} #{y}) scale(#{scale})" fill="none" stroke="#{color}" stroke-width="#{WORD_STROKE}" stroke-linejoin="miter">#{paths}</g>)
end

def svg(view_box, title, body)
  <<~SVG
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="#{view_box.join(' ')}" role="img" aria-labelledby="titulo">
      <title id="titulo">#{title}</title>
      #{body}
    </svg>
  SVG
end

# Composições: mesmo símbolo e mesmo desenho das letras. Cada uma devolve [viewBox, conteúdo].
LAYOUTS = {
  "simbolo" => ->(tone, id) { [ [ 0, 2, 100, 110 ], symbol_group(tone, id) ] },
  "logo-horizontal" => lambda do |tone, id|
    scale = 0.5
    [ [ 0, 2, 100 + 24 + WORD_WIDTH * scale + 2, 110 ],
      symbol_group(tone, id) + word_group(tone, x: 124, y: 57 - 50 * scale, scale: scale, id: id) ]
  end,
  "logo-vertical" => lambda do |tone, id|
    scale = 0.36
    word = WORD_WIDTH * scale
    width = [ 100, word ].max + 8
    [ [ -(width - 100) / 2.0, 2, width, 110 + 16 + 100 * scale + 2 ],
      symbol_group(tone, id) + word_group(tone, x: 50 - word / 2, y: 112 + 14, scale: scale, id: id) ]
  end
}.freeze

PNG_HEIGHT = { "simbolo" => 1024, "logo-horizontal" => 512, "logo-vertical" => 1024 }.freeze

def render(svg_source, height:)
  natural = Vips::Image.svgload_buffer(svg_source)
  Vips::Image.svgload_buffer(svg_source, scale: height.to_f / natural.height)
end

# Ícone quadrado: símbolo centralizado, com fundo opcional (ícone "maskable" do PWA).
def square_icon(size, tone:, ratio:, background: nil)
  view_box, body = LAYOUTS.fetch("simbolo").call(tone, "icone")
  mark = render(svg(view_box, "SGU", body), height: (size * ratio).round)
  canvas = Vips::Image.black(size, size, bands: 4).copy(interpretation: :srgb)
  canvas = (canvas + (background + [ 255 ])).cast(:uchar) if background
  canvas.composite2(mark, :over, x: (size - mark.width) / 2, y: (size - mark.height) / 2).cast(:uchar)
end

FileUtils.mkdir_p(BRAND_DIR)
artboard = []
LAYOUTS.each_with_index do |(name, build), column|
  TONES.each_key.with_index do |tone, row|
    base = tone == "padrao" ? "sgu-#{name}" : "sgu-#{name}-negativo"
    view_box, body = build.call(tone, tone)
    source = svg(view_box, "SGU", body)
    File.write(File.join(BRAND_DIR, "#{base}.svg"), source)
    render(source, height: PNG_HEIGHT.fetch(name)).pngsave(File.join(BRAND_DIR, "#{base}.png"), compression: 9)

    # Prancheta editável: cada versão em um grupo nomeado, sobre uma amostra do fundo indicado.
    _, placed = build.call(tone, "#{name}-#{tone}")
    cell_x = 20 + column * 400
    cell_y = 20 + row * 300
    scale = [ 300.0 / view_box[2], 200.0 / view_box[3] ].min.round(4)
    x = cell_x + (380 - view_box[2] * scale) / 2 - view_box[0] * scale
    y = cell_y + (260 - view_box[3] * scale) / 2 - view_box[1] * scale
    background = tone == "padrao" ? "#F4F7F5" : "#0D171A"
    artboard << %(<g id="#{base}"><rect x="#{cell_x}" y="#{cell_y}" width="380" height="260" rx="16" fill="#{background}"/>) +
      %(<g transform="translate(#{x.round(2)} #{y.round(2)}) scale(#{scale})">#{placed}</g></g>)
  end
end
File.write(File.join(BRAND_DIR, "sgu-marca-fonte.svg"),
           svg([ 0, 0, 1220, 620 ], "Marca SGU: prancheta com símbolo, logotipo horizontal e vertical (padrão e negativo)", artboard.join("\n")))

# Ícones do navegador e do PWA: versão negativa, legível em abas claras e escuras.
square_icon(512, tone: "negativo", ratio: 0.9).pngsave(File.join(ROOT, "public/icon.png"), compression: 9)
square_icon(512, tone: "negativo", ratio: 0.62, background: [ 21, 60, 54 ]).pngsave(File.join(ROOT, "public/icon-maskable.png"), compression: 9)
square_icon(64, tone: "negativo", ratio: 0.94).pngsave(File.join(ROOT, "app/assets/images/favicon.png"), compression: 9)
view_box, body = LAYOUTS.fetch("simbolo").call("negativo", "favicon")
File.write(File.join(ROOT, "public/icon.svg"), svg(view_box, "SGU", body))
puts "Marca gerada em #{BRAND_DIR}"
