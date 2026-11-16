class EmailConfirmationsController < ApplicationController
  allow_unauthenticated_access only: %i[show update]
  rate_limit to: 3, within: 1.hour, only: :create

  def show
    @token = params[:token]
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Cache-Control"] = "no-store"
  end

  def create
    user = Current.user
    return redirect_to edit_profile_path, notice: "E-mail já confirmado." if user.email_confirmed_at?
    unless Notifications::ChannelConfig.email_available?
      return redirect_to edit_profile_path, alert: "Envio de e-mail indisponível."
    end

    NotificationMailer.confirm_email(user).deliver_later
    redirect_to edit_profile_path, notice: "Solicitação de envio registrada."
  end

  def update
    token = params[:token].to_s
    user = User.find_by_token_for(:email_confirmation, token)
    confirmed = user&.with_lock do
      if !user.deleted_at? && User.find_by_token_for(:email_confirmation, token)
        user.update!(email_confirmed_at: Time.current)
      end
    end
    message = confirmed ? { notice: "E-mail confirmado." } : { alert: "Link inválido, expirado ou já utilizado." }
    redirect_to new_session_path, status: :see_other, flash: message
  end
end
