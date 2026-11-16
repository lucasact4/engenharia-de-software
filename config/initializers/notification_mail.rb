if Rails.env.production? && ENV["SGU_SMTP_ADDRESS"].present?
  Rails.application.configure do
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.raise_delivery_errors = true
    config.action_mailer.smtp_settings = {
      address: ENV.fetch("SGU_SMTP_ADDRESS"),
      port: Integer(ENV.fetch("SGU_SMTP_PORT", "587")),
      user_name: ENV["SGU_SMTP_USERNAME"].presence,
      password: ENV["SGU_SMTP_PASSWORD"].presence,
      authentication: (:plain if ENV["SGU_SMTP_USERNAME"].present?),
      enable_starttls: true,
      enable_starttls_auto: false,
      openssl_verify_mode: "peer",
      open_timeout: 5,
      read_timeout: 5
    }
    if ENV["SGU_MAILER_HOST"].present?
      config.action_mailer.default_url_options = {
        host: ENV.fetch("SGU_MAILER_HOST"),
        protocol: "https"
      }
    end
  end
end
