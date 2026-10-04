class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[ edit update ]

  def new
  end

  def create
    if user = User.find_by(email_address: params[:email_address])
      PasswordsMailer.reset(user).deliver_later
    end

    redirect_to new_session_path, notice: t("authentication.passwords.instructions_sent")
  end

  def edit
  end

  def update
    @user.assign_attributes(params.permit(:password, :password_confirmation))
    if @user.save(context: :password_change)
      redirect_to new_session_path, notice: t("authentication.passwords.reset_success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to new_password_path, alert: t("authentication.passwords.invalid_or_expired_link")
    end
end
