module Alerts
  # Gera um protocolo opaco para consulta, independente da chave de idempotência.
  module Protocol
    ALPHABET = (("A".."Z").to_a + ("2".."9").to_a - %w[I O]).freeze

    def self.generate
      chars = Array.new(10) { ALPHABET[SecureRandom.random_number(ALPHABET.size)] }.join
      "SGU-#{chars[0, 5]}-#{chars[5, 5]}"
    end
  end
end
