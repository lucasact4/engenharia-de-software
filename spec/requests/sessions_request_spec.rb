require "rails_helper"

RSpec.describe "Sessions", type: :request do
  describe "GET /session/new" do
    it "renders sign in page" do
      get new_session_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /session" do
    let!(:user) { create(:user, password: "123", password_confirmation: "123") }

    it "creates a session and redirects when credentials are valid" do
      expect do
        post session_path, params: { email_address: user.email_address, password: "123" }
      end.to change(Session, :count).by(1)

      expect(response).to redirect_to(panel_path(locale: I18n.locale))
      expect(Session.last.user).to eq(user)
    end

    it "sends administrators to the administration by default" do
      admin = create(:user, :admin, password: "123", password_confirmation: "123")
      post session_path, params: { email_address: admin.email_address, password: "123" }

      expect(response).to redirect_to(admin_path(locale: I18n.locale))
    end

    it "returns to a stored internal path after login" do
      get new_session_path(return_to: "/mural/1")
      post session_path, params: { email_address: user.email_address, password: "123" }

      expect(response).to redirect_to("/mural/1")
    end

    it "ignores external or protocol-relative return paths" do
      [ "https://evil.example", "//evil.example", "/\\evil.example", "javascript:alert(1)" ].each do |target|
        get new_session_path(return_to: target)
        post session_path, params: { email_address: user.email_address, password: "123" }

        expect(response).to redirect_to(panel_path(locale: I18n.locale))
        delete session_path
      end
    end

    it "redirects back to sign in when credentials are invalid" do
      expect do
        post session_path, params: { email_address: user.email_address, password: "wrong-password" }
      end.not_to change(Session, :count)

      expect(response).to redirect_to(new_session_path(locale: I18n.locale))
      expect(flash[:alert]).to eq(I18n.t("authentication.sessions.invalid_credentials"))
    end

    it "does not create a session for a deactivated user" do
      user.update!(deleted_at: Time.current)

      expect do
        post session_path, params: { email_address: user.email_address, password: "123" }
      end.not_to change(Session, :count)

      expect(response).to redirect_to(new_session_path(locale: I18n.locale))
      expect(flash[:alert]).to eq(I18n.t("authentication.sessions.invalid_credentials"))
    end

    it "returns a user to the requested page after sign in" do
      admin = create(:user, :admin, password: "123", password_confirmation: "123")

      get admin_users_path
      post session_path, params: { email_address: admin.email_address, password: "123" }

      expect(response.headers["Location"]).to include("/admin/users")
    end

    it "temporarily limits repeated sign in attempts" do
      10.times do
        post session_path, params: { email_address: user.email_address, password: "wrong-password" }
      end

      post session_path, params: { email_address: user.email_address, password: "wrong-password" }

      expect(response).to redirect_to(new_session_path(locale: I18n.locale))
      expect(flash[:alert]).to eq(I18n.t("authentication.sessions.rate_limited"))
    end
  end

  describe "DELETE /session" do
    let!(:user) { create(:user, password: "123", password_confirmation: "123") }

    it "terminates current session and redirects to sign in page" do
      sign_in(user)
      current_session = Session.last

      expect do
        delete session_path
      end.to change(Session, :count).by(-1)

      expect(Session.exists?(current_session.id)).to be(false)
      expect(response).to redirect_to(new_session_path(locale: I18n.locale))
    end
  end
end
