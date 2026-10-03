class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: t("authentication.sessions.rate_limited") }

  # ?return_to= vindo do mural (ex.: "Entre para comentar") aceita apenas caminho interno.
  def new
    return_to = Authentication.safe_return_path(params[:return_to])
    session[:return_to_after_authenticating] = return_to if return_to
  end

  def create
    user = User.authenticate_by(params.permit(:email_address, :password))

    if user&.active?
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
end
