# Política do cadastro e da troca de senha; senhas antigas continuam válidas no login.
module PasswordRequirements
  MIN_LENGTH = 8
  MAX_BYTES = 72

  def self.errors(password)
    value = password.to_s
    errors = []
    errors << "deve ter pelo menos #{MIN_LENGTH} caracteres" if value.length < MIN_LENGTH
    errors << "deve conter uma letra maiúscula" unless value.match?(/[[:upper:]]/)
    errors << "deve conter uma letra minúscula" unless value.match?(/[[:lower:]]/)
    errors << "deve conter um número" unless value.match?(/[0-9]/)
    errors << "deve conter um símbolo (ex.: !, @, #)" unless value.match?(/[^[:alnum:]\s]/)
    errors << "deve ter no máximo #{MAX_BYTES} bytes" if value.bytesize > MAX_BYTES
    errors
  end
end
