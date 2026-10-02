# Perfil salvo da apresentação (/apresentacao): escolhe a entrega e quais slides e conteúdos
# do catálogo (config/presentation/roteiro.yml) aparecem. Não guarda conteúdo editorial.
#
# selections: { "gestao" => true, "gestao.reunioes" => false, ... }
#   Chaves ausentes usam o padrão do roteiro; ver Presentation::Selection.
#
# Estas opções controlam só a exibição. Conteúdo oculto continua no HTML público.
class PresentationProfile < ApplicationRecord
  STRICT_BOOLEANS = { true => true, false => false, "1" => true, "0" => false, "true" => true, "false" => false }.freeze

  attribute :selections, :json, default: -> { {} }

  validates :name, presence: true, length: { maximum: 80 }, uniqueness: { case_sensitive: false }
  validates :description, length: { maximum: 500 }
  validate :delivery_must_exist
  validate :selections_must_match_catalog, if: -> { new_record? || will_save_change_to_selections? }

  before_save :deactivate_other_profiles, if: -> { active? && will_save_change_to_active? }

  scope :ordered, -> { order(active: :desc, name: :asc) }

  # Perfil pedido em ?perfil=<id> ou, na falta dele, o perfil ativo. Nunca cria registros.
  def self.for_presentation(requested_id = nil)
    (find_by(id: requested_id) if requested_id.to_s.match?(/\A\d+\z/)) || find_by(active: true)
  end

  # Valores vindos do formulário ("1"/"0") viram booleanos; qualquer outro valor é mantido
  # como veio para que a validação o rejeite.
  def selections=(value)
    hash = value.respond_to?(:to_unsafe_h) ? value.to_unsafe_h : value.to_h
    super(hash.to_h { |key, choice| [ key.to_s, STRICT_BOOLEANS.fetch(choice, choice) ] })
  end

  def activate!
    update!(active: true)
  end

  def selection(presentation = Presentation.load)
    Presentation::Selection.new(presentation, selections, delivery_id: delivery, profile_name: name)
  end

  private

    def presentation
      @presentation ||= Presentation.load
    end

    def delivery_must_exist
      errors.add(:delivery, :inclusion) unless presentation.delivery(delivery)
    end

    def selections_must_match_catalog
      unless selections.is_a?(Hash)
        errors.add(:selections, :invalid)
        return
      end

      unknown = selections.keys.reject { |key| presentation.catalog_key?(key) }
      errors.add(:selections, :unknown_keys, keys: unknown.join(", ")) if unknown.any?

      invalid = selections.reject { |_key, value| [ true, false ].include?(value) }.keys
      errors.add(:selections, :not_boolean, keys: invalid.join(", ")) if invalid.any?

      hidden_required = Presentation::REQUIRED_SLIDES.select { |id| selections[id] == false }
      errors.add(:selections, :required_slides, slides: hidden_required.join(", ")) if hidden_required.any?
    end

    def deactivate_other_profiles
      self.class.where(active: true).where.not(id: id).update_all(active: false, updated_at: Time.current)
    end
end
