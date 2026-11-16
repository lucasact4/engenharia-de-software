require "rails_helper"

RSpec.describe "RF004 Google sign-in", type: :request do
  let(:subject_id) { "test-google-subject-123" }
  let(:user) { create(:user, email_address: "estudante@ufrpe.br") }
  let(:settings) do
    {
      "SGU_GOOGLE_CLIENT_ID" => "test-client.apps.googleusercontent.com",
      "SGU_GOOGLE_CLIENT_SECRET" => "fake-client-secret",
      "SGU_GOOGLE_REDIRECT_URI" => "https://sgu.example.test/entrar/google/retorno"
    }
  end

  around do |example|
    previous = ENV.to_h.slice(*settings.keys)
    ENV.update(settings)
    example.run
  ensure
    settings.each_key { |key| ENV[key] = previous[key] }
  end

  def begin_attempt(path = google_sign_in_path, **params)
    post path, params: params
    expect(response).to have_http_status(:see_other)
    uri = URI.parse(response.location)
    expect(uri.host).to eq("accounts.google.com")
    URI.decode_www_form(uri.query).to_h
  end

  def return_from_google(attempt, **params)
    get google_sign_in_callback_path, params: { state: attempt.fetch("state"), code: "test-code" }.merge(params)
  end

  it "links from the authenticated profile using the SGU password, then signs in by the encrypted Google subject" do
    sign_in(user)
    get edit_profile_path
    expect(response.body).to include("Vincular conta Google")
    connection = begin_attempt(google_connection_path, password: user.password)
    expect(connection).to include(
      "client_id" => settings.fetch("SGU_GOOGLE_CLIENT_ID"), "scope" => "openid email",
      "redirect_uri" => settings.fetch("SGU_GOOGLE_REDIRECT_URI"), "code_challenge_method" => "S256"
    )
    expect(connection).not_to have_key("client_secret")
    expect(GoogleSignIn).to receive(:exchange) do |code:, nonce:, verifier:|
      expect(code).to eq("test-code")
      expect(nonce).to eq(connection.fetch("nonce"))
      expect(Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)).to eq(connection.fetch("code_challenge"))
      subject_id
    end
    return_from_google(connection)
    expect(response).to redirect_to(edit_profile_path(locale: I18n.locale))
    expect(user.reload.google_subject).to eq(subject_id)
    expect(user.ciphertext_for(:google_subject)).not_to include(subject_id)
    expect(user.email_address).to eq("estudante@ufrpe.br")

    sign_out
    get profile_path
    login = begin_attempt
    allow(GoogleSignIn).to receive(:exchange).and_return(subject_id)
    expect { return_from_google(login) }.to change { user.sessions.count }.by(1)
    expect(response).to redirect_to(profile_path)
    expect(response.headers["Cache-Control"]).to eq("no-store")
    expect(response.headers["Referrer-Policy"]).to eq("no-referrer")
    follow_redirect!
    expect(response).to have_http_status(:ok)
  end

  it "requires a local session and the SGU password before starting a link" do
    post google_connection_path, params: { password: user.password }
    expect(response).to redirect_to(new_session_path(locale: I18n.locale))

    sign_in(user)
    post google_connection_path, params: { password: "incorreta" }
    expect(response).to redirect_to(edit_profile_path(locale: I18n.locale))
    expect(flash[:alert]).to include("senha atual")
    expect(user.reload.google_subject).to be_nil
  end

  it "does not create an account or sign in an unlinked identity" do
    user
    allow(GoogleSignIn).to receive(:exchange).and_return(subject_id)
    attempt = begin_attempt
    expect { return_from_google(attempt) }.not_to change(User, :count)
    expect(user.reload.google_subject).to be_nil
    expect(user.sessions).to be_empty
    expect(flash[:alert]).to include("vincule uma conta Google")
  end

  it "checks the state, expires old attempts and consumes them before the exchange" do
    expect(GoogleSignIn).not_to receive(:exchange)
    attempt = begin_attempt
    return_from_google(attempt, state: "different-state")
    expect(flash[:alert]).to include("expirou ou é inválida")
    return_from_google(attempt)
    expect(flash[:alert]).to include("expirou ou é inválida")

    new_attempt = begin_attempt
    travel 11.minutes do
      return_from_google(new_attempt)
      expect(flash[:alert]).to include("expirou ou é inválida")
    end
  end

  it "rejects a link callback if the local session was replaced" do
    expect(GoogleSignIn).not_to receive(:exchange)
    sign_in(user)
    attempt = begin_attempt(google_connection_path, password: user.password)
    sign_out
    other = create(:user)
    sign_in(other)
    return_from_google(attempt)
    expect(flash[:alert]).to include("expirou ou é inválida")
    expect(other.reload.google_subject).to be_nil
    expect(user.reload.google_subject).to be_nil
  end

  it "refuses a Google identity already linked to another SGU account" do
    other = create(:user, google_subject: subject_id)
    sign_in(user)
    attempt = begin_attempt(google_connection_path, password: user.password)
    allow(GoogleSignIn).to receive(:exchange).and_return(subject_id)
    return_from_google(attempt)
    expect(flash[:alert]).to include("já está vinculada")
    expect(user.reload.google_subject).to be_nil
    expect(other.reload.google_subject).to eq(subject_id)
  end

  it "honors existing approval and deactivation rules" do
    allow(GoogleSignIn).to receive(:exchange).and_return(subject_id)
    user.update!(google_subject: subject_id, registration_status: "pending")
    return_from_google(begin_attempt)
    expect(flash[:alert]).to include("vincule uma conta Google")
    user.update!(registration_status: "approved", deleted_at: Time.current)
    return_from_google(begin_attempt)
    expect(user.sessions).to be_empty
    expect(flash[:alert]).to include("vincule uma conta Google")
  end

  it "allows only the authenticated account to remove its link and denies later Google sign-in" do
    user.update!(google_subject: subject_id)
    delete google_connection_path
    expect(user.reload.google_subject).to eq(subject_id)
    sign_in(user)
    delete google_connection_path
    expect(flash[:notice]).to include("desvinculada")
    expect(user.reload.google_subject).to be_nil
    sign_out
    allow(GoogleSignIn).to receive(:exchange).and_return(subject_id)
    return_from_google(begin_attempt)
    expect(user.sessions).to be_empty
  end

  it "reports a canceled consent flow without exchanging a code" do
    attempt = begin_attempt
    expect(GoogleSignIn).not_to receive(:exchange)
    return_from_google(attempt, code: nil, error: "access_denied")
    expect(flash[:alert]).to include("cancelada")
  end

  {
    GoogleSignIn::InvalidResponse => "validar",
    GoogleSignIn::Unavailable => "indisponível"
  }.each do |exception, message|
    it "leaves the browser signed out when Google returns #{exception.name.demodulize}" do
      attempt = begin_attempt
      allow(GoogleSignIn).to receive(:exchange).and_raise(exception)
      expect { return_from_google(attempt) }.not_to change(Session, :count)
      expect(flash[:alert]).to include(message)
    end
  end

  it "keeps password login available when the Google configuration is missing" do
    ENV.delete("SGU_GOOGLE_CLIENT_SECRET")
    get new_session_path
    expect(response.body).not_to include("Entrar com Google")
    post google_sign_in_path
    expect(flash[:alert]).to include("indisponível")
    sign_in(user)
    expect(response).to redirect_to(panel_path(locale: I18n.locale))
  end
end
