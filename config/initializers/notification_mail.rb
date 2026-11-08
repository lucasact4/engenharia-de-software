if !Rails.env.test? && ENV["SGU_SMTP_ADDRESS"].present?
  Rails.application.configure do
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: ENV.fetch("SGU_SMTP_ADDRESS"),
      port: Integer(ENV.fetch("SGU_SMTP_PORT", "587")),
      user_name: ENV["SGU_SMTP_USERNAME"],
      password: ENV["SGU_SMTP_PASSWORD"],
      authentication: (:plain if ENV["SGU_SMTP_USERNAME"].present?),
      enable_starttls: true,
      openssl_verify_mode: "peer",
      open_timeout: 5,
      read_timeout: 5
    }
  end
end
