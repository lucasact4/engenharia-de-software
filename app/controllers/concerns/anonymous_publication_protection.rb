module AnonymousPublicationProtection
  extend ActiveSupport::Concern

  private

    def anonymous_publication_verified?(attributes)
      return true unless ActiveModel::Type::Boolean.new.cast(attributes[:anonymous_public])

      TurnstileVerifier.verify(params["cf-turnstile-response"], expected_hostname: request.host)
    end

    def turnstile_error_message
      if TurnstileVerifier.configured?
        "Não foi possível confirmar o desafio antirobô. Tente novamente."
      else
        "A publicação com identidade oculta está indisponível até que a proteção Turnstile seja configurada."
      end
    end
end
