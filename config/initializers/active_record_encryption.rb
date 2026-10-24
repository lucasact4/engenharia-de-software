# Deriva chaves de propósito específico da chave secreta estável já exigida pelo Rails.
# Não altere SECRET_KEY_BASE em produção sem planejar a rotação dos dados criptografados.
secret = Rails.application.secret_key_base
key_generator = ActiveSupport::KeyGenerator.new(secret, iterations: 65_536)

Rails.application.config.active_record.encryption.primary_key = key_generator.generate_key("sgu/active-record-encryption/primary", 32)
Rails.application.config.active_record.encryption.deterministic_key = key_generator.generate_key("sgu/active-record-encryption/deterministic", 32)
Rails.application.config.active_record.encryption.key_derivation_salt = "sgu/active-record-encryption/v1"
