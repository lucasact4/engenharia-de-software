# Filtros de dados sensíveis; reinicie o servidor ao alterar esta configuração.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cpf, :cnpj,
  :mother_name, :business_name, :phone, :identifier, :term, :cvv, :cvc,
  # Coordenadas informadas em alertas (dado pessoal de localização).
  :latitude, :longitude
]
