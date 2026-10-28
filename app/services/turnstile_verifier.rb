require "net/http"
require "json"
require "uri"

# Verifica no servidor os tokens Turnstile de publicações com identidade oculta.
# O IP do visitante e o token nunca são registrados em logs.
class TurnstileVerifier
  SITEVERIFY_URI = URI("https://challenges.cloudflare.com/turnstile/v0/siteverify")
  TIMEOUT_SECONDS = 3
  MAX_TOKEN_LENGTH = 2048

  class << self
    def site_key
      ENV["TURNSTILE_SITE_KEY"].to_s.strip.presence
    end

    def configured?
      site_key.present? && secret_key.present?
    end

    def verify(token, expected_hostname: nil)
      token = token.to_s
      return false unless configured? && token.present? && token.length <= MAX_TOKEN_LENGTH

      request = Net::HTTP::Post.new(SITEVERIFY_URI)
      request.set_form_data(secret: secret_key, response: token)
      http = Net::HTTP.new(SITEVERIFY_URI.host, SITEVERIFY_URI.port)
      http.use_ssl = true
      http.open_timeout = TIMEOUT_SECONDS
      http.read_timeout = TIMEOUT_SECONDS
      response = http.start { |connection| connection.request(request) }
      return false unless response.is_a?(Net::HTTPSuccess)

      result = JSON.parse(response.body)
      result["success"] == true &&
        result["action"] == "anonymous_occurrence" &&
        (expected_hostname.blank? || result["hostname"].to_s.casecmp?(expected_hostname.to_s))
    rescue StandardError
      false
    end

    private

      def secret_key
        ENV["TURNSTILE_SECRET_KEY"].to_s.strip.presence
      end
  end
end