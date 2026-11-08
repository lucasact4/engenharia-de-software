class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: t("authentication.sessions.rate_limited") }

  # ?return_to= vindo do mural (ex.: "Entre para comentar") aceita apenas caminho interno.
  def new
    return_to = Authentication.safe_return_path(params[:return_to])
    session[:return_to_after_authenticating] = return_to if return_to
  end

  def create
    identifier = params[:identifier].presence || params[:email_address]
    user = authenticate_identifier(identifier, params[:password])

    if user
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: t("authentication.sessions.invalid_credentials")
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path
  end

  private

    def authenticate_identifier(value, password)
      identifier = value.to_s.strip
      return if identifier.blank?

      candidates = if identifier.include?("@")
        User.active.where(email_address: identifier.downcase)
      else
        digits = identifier.gsub(/\D/, "")
        return if digits.blank?

        User.active.where(cpf: digits).or(User.active.where(phone: digits))
      end

      # Um número pode identificar duas contas: CPF de uma e telefone de outra.
      # Só entra quando a senha corresponde a uma única conta ativa.
      authenticated = candidates.select { |candidate| candidate.authenticate(password) }
      authenticated.first if authenticated.one?
    end
end
