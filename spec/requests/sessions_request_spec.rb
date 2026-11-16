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

  describe "POST /session with email, CPF or phone" do
    let(:password) { "SenhaCpf123!" }
    let!(:person) do
      create(:user, email_address: "identificador@example.com", cpf: "12345678909", phone: "81988887777",
        password: password, password_confirmation: password)
    end

    {
      "case-insensitive email" => "IDENTIFICADOR@EXAMPLE.COM",
      "plain CPF" => "12345678909",
      "formatted CPF" => "123.456.789-09",
      "plain phone" => "81988887777",
      "formatted phone" => "(81) 98888-7777"
    }.each do |label, identifier|
      it "authenticates the correct account using #{label}" do
        expect do
          post session_path, params: { identifier: identifier, password: password }
        end.to change(person.sessions, :count).by(1)

        expect(response).to redirect_to(panel_path(locale: I18n.locale))
        expect(Session.last.user).to eq(person)
      end
    end

    it "does not reject a matching CPF and phone belonging to the same account" do
      person.update!(phone: person.cpf)

      expect do
        post session_path, params: { identifier: person.cpf, password: password }
      end.to change(person.sessions, :count).by(1)
      expect(Session.last.user).to eq(person)
    end

    it "rejects empty identifiers without creating a session" do
      [ nil, "", "   " ].each do |identifier|
        expect do
          post session_path, params: { identifier: identifier, password: password }
        end.not_to change(Session, :count)
        expect(response).to redirect_to(new_session_path(locale: I18n.locale))
      end
    end

    context "when another account's phone matches the CPF" do
      let(:other_password) { "SenhaTelefone456!" }
      let!(:phone_owner) do
        create(:user, email_address: "telefone@example.com", phone: person.cpf,
          password: other_password, password_confirmation: other_password)
      end

      it "authenticates the phone owner with their correct password" do
        expect do
          post session_path, params: { identifier: phone_owner.phone, password: other_password }
        end.to change(phone_owner.sessions, :count).by(1)

        expect(person.sessions.count).to eq(0)
        expect(Session.last.user).to eq(phone_owner)
      end

      it "authenticates the CPF owner with their correct password" do
        expect do
          post session_path, params: { identifier: person.cpf, password: password }
        end.to change(person.sessions, :count).by(1)

        expect(phone_owner.sessions.count).to eq(0)
        expect(Session.last.user).to eq(person)
      end

      it "rejects a password that matches neither account" do
        expect do
          post session_path, params: { identifier: person.cpf, password: "senha-incorreta" }
        end.not_to change(Session, :count)

        expect(response).to redirect_to(new_session_path(locale: I18n.locale))
      end

      [ "deactivated", "pending", "rejected" ].each do |state|
        it "allows the active phone owner when the CPF account is #{state}" do
          if state == "deactivated"
            person.update!(deleted_at: Time.current)
          else
            person.update!(registration_status: state)
          end

          expect do
            post session_path, params: { identifier: phone_owner.phone, password: other_password }
          end.to change(phone_owner.sessions, :count).by(1)
          expect(person.sessions.count).to eq(0)
          expect(Session.last.user).to eq(phone_owner)
        end
      end

      it "does not authenticate an inactive phone owner even if their password matches" do
        phone_owner.update!(deleted_at: Time.current)

        expect do
          post session_path, params: { identifier: phone_owner.phone, password: other_password }
        end.not_to change(Session, :count)
        expect(response).to redirect_to(new_session_path(locale: I18n.locale))
      end

      context "when both active accounts share the password" do
        let(:other_password) { password }

        it "rejects the ambiguous numeric identifier instead of choosing an account" do
          expect do
            post session_path, params: { identifier: person.cpf, password: password }
          end.not_to change(Session, :count)

          expect(response).to redirect_to(new_session_path(locale: I18n.locale))
          expect(flash[:alert]).to eq(I18n.t("authentication.sessions.invalid_credentials"))
        end

        it "still permits each account to authenticate unambiguously by email" do
          [ person, phone_owner ].each do |account|
            expect do
              post session_path, params: { identifier: account.email_address, password: password }
            end.to change(account.sessions, :count).by(1)

            expect(Session.last.user).to eq(account)
            delete session_path
          end
        end

        it "ignores an inactive CPF account when only the active phone account matches" do
          person.update!(deleted_at: Time.current)

          expect do
            post session_path, params: { identifier: phone_owner.phone, password: password }
          end.to change(phone_owner.sessions, :count).by(1)
          expect(Session.last.user).to eq(phone_owner)
        end
      end
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
