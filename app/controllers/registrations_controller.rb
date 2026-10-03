# Cadastro institucional aberto nesta fase, com aviso explícito sobre aprovação e e-mail.
class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  before_action :redirect_authenticated
  rate_limit to: 10, within: 1.hour, only: :create,
             with: -> { redirect_to new_registration_path, alert: "Muitas tentativas de cadastro. Tente novamente mais tarde." }

  def new
    @registration = Registration.new
  end

  def create
    @registration = Registration.new(registration_params)
    user = Users::Register.call(registration: @registration)
    if user.active?
      start_new_session_for(user)
      redirect_to panel_path, notice: "Conta criada e liberada nesta fase de desenvolvimento. A confirmação de e-mail ainda não está disponível."
    else
      redirect_to new_session_path, notice: "Cadastro recebido. Aguarde a aprovação da administração para entrar. A confirmação de e-mail ainda não está disponível."
    end
  rescue ActiveModel::ValidationError
    render_invalid
  rescue ActiveRecord::RecordInvalid => error
    error.record.errors.each { |item| @registration.errors.add(item.attribute, item.message) }
    render_invalid
  rescue ActiveRecord::RecordNotUnique
    @registration.errors.add(:email_address, "já está em uso")
    render_invalid
  end

  private

    def registration_params
      params.require(:registration).permit(:display_name, :email_address, :role_code, :password, :password_confirmation)
    end

    def redirect_authenticated
      redirect_to panel_path if authenticated?
    end

    def render_invalid
      @registration.password = nil
      @registration.password_confirmation = nil
      render :new, status: :unprocessable_content
    end
end
