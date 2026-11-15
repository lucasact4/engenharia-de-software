# Filtros de dados sensíveis; reinicie o servidor ao alterar esta configuração.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cpf, :cnpj,
  :mother_name, :business_name, :phone, :identifier, :term, :creator, /\Aq\z/, :cvv, :cvc,
  :"cf-turnstile-response", :cf_turnstile_response, :google_subject, /\A(?:code|state|nonce|code_verifier)\z/,
  # Coordenadas informadas em alertas (dado pessoal de localização).
  :latitude, :longitude, :subscription, /\A(?:endpoint|p256dh|auth)\z/
]

Rails.application.config.filter_redirect += [ "accounts.google.com/o/oauth2" ]
