# Leitura de config/presentation/retrospectiva.yml compartilhada pelos slides "retrospectiva"
# e "status-report". Aceita o formato atual (colunas de cartões) e o anterior (pontos/licoes).
class Presentation::Retrospective
  Card = Struct.new(:title, :text, keyword_init: true) do
    def to_s = [ title, text ].compact_blank.join(": ")
  end
  Column = Struct.new(:id, :title, :cards, keyword_init: true)
  Action = Struct.new(:text, :owner, :deadline, keyword_init: true)

  LESSONS_COLUMN = "aprendi"
  GAPS_COLUMN = "faltou"
  POINTS_COLUMNS = %w[gostei faltou].freeze

  attr_reader :date, :tool, :format, :link, :image, :zoom_image, :image_alt, :columns, :actions

  def initialize(data)
    @date = data[:data]
    @tool = data[:ferramenta].presence
    @format = data[:formato].presence
    @link = data[:link].presence
    @image = data[:imagem].presence
    @zoom_image = data[:imagem_ampliada].presence || @image
    @image_alt = data[:imagem_descricao].presence || "Registro da retrospectiva da equipe"
    @columns = Array(data[:colunas]).map do |column|
      Column.new(id: column[:id], title: column[:titulo],
                 cards: Array(column[:cartoes]).map { |card| Card.new(title: card[:titulo].presence, text: card[:texto].presence) })
    end
    @legacy_points = Array(data[:pontos]).map { |point| Card.new(text: point.to_s) }
    @legacy_lessons = Array(data[:licoes]).map { |lesson| Card.new(text: lesson.to_s) }
    @actions = Array(data[:acoes]).map do |action|
      action.is_a?(Hash) ? Action.new(text: action[:acao], owner: action[:responsavel], deadline: action[:prazo]) : Action.new(text: action.to_s)
    end
  end

  def column(id) = columns.find { |column| column.id == id }

  # O que aprendemos: coluna "aprendi" do quadro ou, no formato anterior, a lista "licoes".
  def lessons = column(LESSONS_COLUMN)&.cards || @legacy_lessons

  # Pontos a melhorar levantados no quadro (não são ações combinadas).
  def gaps = column(GAPS_COLUMN)&.cards || []

  def points
    return @legacy_points if columns.empty?

    POINTS_COLUMNS.filter_map { |id| column(id) }.flat_map(&:cards)
  end

  def image? = image.present?
  def registered? = image? || columns.any? || @legacy_points.any? || @legacy_lessons.any? || actions.any?

  def validate!
    if link && !link.match?(%r{\Ahttps://[^\s]+\z})
      raise ArgumentError, "retrospectiva.yml: link deve ser um endereço https:// público."
    end

    ids = columns.map(&:id)
    unless ids.all? { |id| id.is_a?(String) && id.match?(Presentation::IDENTIFIER) } && ids.uniq.size == ids.size
      raise ArgumentError, "retrospectiva.yml: cada coluna precisa de um id único (letras minúsculas, números e hífens)."
    end

    columns.each do |column|
      if column.title.blank? || column.cards.any? { |card| card.text.blank? }
        raise ArgumentError, "retrospectiva.yml: a coluna #{column.id} precisa de titulo e de cartões com texto."
      end
    end
    self
  end
end
