require "rails_helper"

RSpec.describe "Passwords", type: :request do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  before do
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
  end

  describe "GET /passwords/new" do
    it "renders forgot password page" do
      get new_password_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /passwords" do
    let!(:user) { create(:user) }

    it "enqueues reset email when user exists" do
      expect do
        post passwords_path, params: { email_address: user.email_address }
      end.to have_enqueued_mail(PasswordsMailer, :reset).with(user)

      expect(response).to redirect_to(new_session_path(locale: I18n.locale))
      expect(flash[:notice]).to eq(I18n.t("authentication.passwords.instructions_sent"))
    end

    it "does not enqueue reset email when user does not exist" do
      expect do
        post passwords_path, params: { email_address: "missing@example.com" }
      end.not_to have_enqueued_mail(PasswordsMailer, :reset)

      expect(response).to redirect_to(new_session_path(locale: I18n.locale))
      expect(flash[:notice]).to eq(I18n.t("authentication.passwords.instructions_sent"))
    end
  end

  describe "GET /passwords/:token/edit" do
    let!(:user) { create(:user, password: "123", password_confirmation: "123") }

    it "renders edit page for a valid token" do
      get edit_password_path(user.password_reset_token)

      expect(response).to have_http_status(:ok)
    end

    it "redirects to new password page when token is invalid" do
      get edit_password_path("invalid-token")

      expect(response).to redirect_to(new_password_path(locale: I18n.locale))
      expect(flash[:alert]).to eq(I18n.t("authentication.passwords.invalid_or_expired_link"))
    end

    it "rejects an expired reset token" do
      token = user.password_reset_token

      travel 16.minutes do
        get edit_password_path(token)
      end

      expect(response).to redirect_to(new_password_path(locale: I18n.locale))
      expect(flash[:alert]).to eq(I18n.t("authentication.passwords.invalid_or_expired_link"))
    end
  end

  describe "PATCH /passwords/:token" do
    let!(:user) { create(:user, password: "123", password_confirmation: "123") }
    let(:reset_token) { user.password_reset_token }

    it "updates password and redirects when params are valid" do
      patch password_path(reset_token), params: { password: "NovaSenha123!", password_confirmation: "NovaSenha123!" }

      expect(response).to redirect_to(new_session_path(locale: I18n.locale))
      expect(flash[:notice]).to eq(I18n.t("authentication.passwords.reset_success"))
      expect(User.authenticate_by(email_address: user.email_address, password: "NovaSenha123!")).to eq(user.reload)
    end

    it "rejects an absent, weak or unconfirmed new password without changing the digest" do
      digest = user.password_digest
      [ {}, { password: "password", password_confirmation: "password" }, { password: "NovaSenha123!" } ].each do |attributes|
        patch password_path(reset_token), params: attributes
        expect(response).to have_http_status(:unprocessable_content)
        expect(user.reload.password_digest).to eq(digest)
      end
    end

    it "renders validation errors when params are invalid" do
      patch password_path(reset_token), params: { password: "NovaSenha123!", password_confirmation: "mismatch" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Confirmação")
      expect(User.authenticate_by(email_address: user.email_address, password: "123")).to eq(user.reload)
    end
  end
end
