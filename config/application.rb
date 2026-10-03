require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module RailsBase
  class Application < Rails::Application
    config.load_defaults 8.1

    config.autoload_lib(ignore: %w[assets generators tasks templates])

    config.i18n.load_path += Dir[Rails.root.join("my", "locales", "*.{rb,yml}").to_s]
    config.i18n.available_locales = [ :en, "pt-br" ]
    config.i18n.default_locale = "pt-br"
    # Horários exibidos e lidos em formulários no fuso do campus (UFRPE, Recife); o banco guarda UTC.
    config.time_zone = "America/Recife"
    config.x.registration.auto_approve = ENV.fetch("SGU_AUTO_APPROVE_REGISTRATIONS", "true") == "true"
    # O cadastro informa a ausência de envio/verificação de e-mail nesta fase.
    config.x.registration.email_verification_enabled = false

    # Fotos privadas passam pelo controller com autorização; URLs assinadas não bastam.
    config.active_storage.draw_routes = false

    config.generators do |g|
      g.scaffold_controller :my_scaffold_controller
      g.template_engine nil
      g.helper nil
      g.test_framework :rspec, request_specs: false
      g.stylesheets  false
      g.javascripts  false
    end
  end
end
