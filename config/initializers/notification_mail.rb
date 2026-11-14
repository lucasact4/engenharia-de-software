if !Rails.env.test? && ENV["SGU_SMTP_ADDRESS"].present?
  address = ENV.fetch("SGU_SMTP_ADDRESS")
  local_capture = Rails.env.development? && %w[127.0.0.1 ::1].include?(address) &&
    ENV["SGU_SMTP_STARTTLS"] == "false"

  Rails.application.configure do
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.raise_delivery_errors = true
    config.action_mailer.smtp_settings = {
      address: address,
      port: Integer(ENV.fetch("SGU_SMTP_PORT", "587")),
      user_name: ENV["SGU_SMTP_USERNAME"].presence,
      password: ENV["SGU_SMTP_PASSWORD"].presence,
      authentication: (:plain if ENV["SGU_SMTP_USERNAME"].present?),
      enable_starttls: !local_capture,
      enable_starttls_auto: false,
      openssl_verify_mode: "peer",
      open_timeout: 5,
      read_timeout: 5
    }
    if ENV["SGU_MAILER_HOST"].present?
      config.action_mailer.default_url_options = {
        host: ENV.fetch("SGU_MAILER_HOST"),
        protocol: Rails.env.production? || ENV["SGU_MAILER_HTTPS"] == "true" ? "https" : "http"
      }
    end
  end
end
