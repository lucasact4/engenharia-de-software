require "base64"
require "digest"
require "googleauth/id_tokens"
require "json"
require "net/http"

class GoogleSignIn
  AUTHORIZATION_URL = "https://accounts.google.com/o/oauth2/v2/auth"
  TOKEN_URI = URI("https://oauth2.googleapis.com/token").freeze
  CALLBACK_PATH = "/entrar/google/retorno"

  class InvalidResponse < StandardError; end
  class Unavailable < StandardError; end

  def self.configured?
    ENV["SGU_GOOGLE_CLIENT_ID"].present? && ENV["SGU_GOOGLE_CLIENT_SECRET"].present? && redirect_uri.present?
  end

  def self.redirect_uri
    uri = URI.parse(ENV.fetch("SGU_GOOGLE_REDIRECT_URI", ""))
    return unless uri.is_a?(URI::HTTP) && uri.host.present? && uri.path == CALLBACK_PATH
    return if uri.userinfo || uri.query || uri.fragment
    return unless uri.scheme == "https" || (!Rails.env.production? && %w[localhost 127.0.0.1].include?(uri.hostname))

    uri.to_s
  rescue URI::InvalidURIError
    nil
  end

  def self.authorization_url(state:, nonce:, verifier:)
    query = {
      client_id: ENV.fetch("SGU_GOOGLE_CLIENT_ID"),
      redirect_uri: redirect_uri,
      response_type: "code",
      scope: "openid email",
      state: state,
      nonce: nonce,
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false),
      code_challenge_method: "S256",
      prompt: "select_account"
    }
    "#{AUTHORIZATION_URL}?#{URI.encode_www_form(query)}"
  end

  def self.exchange(code:, nonce:, verifier:)
    request = Net::HTTP::Post.new(TOKEN_URI)
    request.set_form_data(
      client_id: ENV.fetch("SGU_GOOGLE_CLIENT_ID"),
      client_secret: ENV.fetch("SGU_GOOGLE_CLIENT_SECRET"),
      code: code,
      code_verifier: verifier,
      grant_type: "authorization_code",
      redirect_uri: redirect_uri
    )
    response = Net::HTTP.start(TOKEN_URI.host, TOKEN_URI.port, use_ssl: true, open_timeout: 3, read_timeout: 5, write_timeout: 5) do |http|
      http.request(request)
    end
    raise InvalidResponse if %w[400 401 403].include?(response.code)
    raise Unavailable unless response.is_a?(Net::HTTPSuccess)

    token_response = JSON.parse(response.body)
    token = token_response["id_token"] if token_response.is_a?(Hash)
    raise InvalidResponse unless token.is_a?(String) && token.present?

    client_id = ENV.fetch("SGU_GOOGLE_CLIENT_ID")
    claims = Google::Auth::IDTokens.verify_oidc(token, aud: client_id)
    raise InvalidResponse unless claims["nonce"] == nonce && claims["email_verified"] == true
    raise InvalidResponse if claims.key?("azp") && claims["azp"] != client_id
    raise InvalidResponse unless claims["exp"].is_a?(Numeric) && claims["exp"] > Time.current.to_i

    subject = claims["sub"]
    raise InvalidResponse unless subject.is_a?(String) && subject.match?(/\A[!-~]{1,255}\z/)

    subject
  rescue Google::Auth::IDTokens::KeySourceError, Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError
    raise Unavailable
  rescue Google::Auth::IDTokens::VerificationError, JSON::ParserError
    raise InvalidResponse
  end
end
