require "rails_helper"
require "jwt"

RSpec.describe GoogleSignIn do
  let(:keys) { OpenSSL::PKey::RSA.generate(2048) }
  let(:jwks) { JWT::JWK.new(keys.public_key, { alg: "RS256", use: "sig" }) }
  let(:token_payload) do
    {
      "iss" => "https://accounts.google.com", "aud" => "rf004-client",
      "sub" => "google-subject-456", "exp" => 5.minutes.from_now.to_i,
      "nonce" => "test-nonce", "email_verified" => true
    }
  end
  let(:settings) do
    {
      "SGU_GOOGLE_CLIENT_ID" => "rf004-client",
      "SGU_GOOGLE_CLIENT_SECRET" => "fake-secret",
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

  def token_response(claims = {}, signing_key: keys)
    id_token = JWT.encode(token_payload.merge(claims), signing_key, "RS256", { kid: jwks.kid })
    reply = Net::HTTPOK.new("1.1", "200", "OK")
    allow(reply).to receive(:body).and_return({ id_token: id_token }.to_json)
    http = instance_double(Net::HTTP)
    expect(http).to receive(:request) do |request|
      expect(request.path).to eq("/token")
      expect(URI.decode_www_form(request.body).to_h).to include(
        "code" => "test-code", "code_verifier" => "test-verifier", "grant_type" => "authorization_code",
        "redirect_uri" => settings.fetch("SGU_GOOGLE_REDIRECT_URI")
      )
      reply
    end
    allow(Net::HTTP).to receive(:start)
      .with("oauth2.googleapis.com", 443, use_ssl: true, open_timeout: 3, read_timeout: 5, write_timeout: 5)
      .and_yield(http)
    key_source = Google::Auth::IDTokens::StaticKeySource.from_jwk_set({ keys: [ jwks.export ] }.to_json)
    allow(Google::Auth::IDTokens).to receive(:oidc_key_source).and_return(key_source)
  end

  def exchange
    described_class.exchange(code: "test-code", nonce: "test-nonce", verifier: "test-verifier")
  end

  it "validates a signed ID token and returns only the stable subject" do
    token_response
    expect(exchange).to eq("google-subject-456")
  end

  {
    "aud" => "different-app",
    "iss" => "https://untrusted.example.test",
    "email_verified" => false,
    "nonce" => "different-flow",
    "exp" => 1,
    "azp" => "different-presenter",
    "sub" => ""
  }.each do |claim, wrong_value|
    it "rejects a token with an invalid #{claim} claim" do
      token_response({ claim => wrong_value })
      expect { exchange }.to raise_error(GoogleSignIn::InvalidResponse)
    end
  end

  it "rejects a token with the wrong signature" do
    token_response(signing_key: OpenSSL::PKey::RSA.generate(2048))
    expect { exchange }.to raise_error(GoogleSignIn::InvalidResponse)
  end

  it "handles a transport timeout as provider unavailability" do
    allow(Net::HTTP).to receive(:start).and_raise(Net::OpenTimeout)
    expect { exchange }.to raise_error(GoogleSignIn::Unavailable)
  end
end
