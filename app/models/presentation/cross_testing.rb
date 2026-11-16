# Conteúdo dos testes cruzados (config/presentation/testes_cruzados.yml): recomendações para a
# equipe testadora e plano de teste do MVP.
class Presentation::CrossTesting
  FILE = Presentation::CONTENT_DIR.join("testes_cruzados.yml")
  KEYS = %w[mvp plano acesso dicas missoes fora_do_escopo reporte].freeze

  KEYS.each do |key|
    define_method(key) { @data.fetch(key) }
  end

  def self.load
    data = YAML.safe_load_file(FILE) || {}
    missing = KEYS - data.keys
    raise ArgumentError, "testes_cruzados.yml sem as chaves: #{missing.join(', ')}" if missing.any?

    new(ActiveSupport::HashWithIndifferentAccess.new(data))
  end

  def initialize(data)
    @data = data
  end

  def report_channel
    channel = reporte[:canal] || {}
    channel if channel[:url].to_s.match?(%r{\Ahttps?://}i)
  end
end
