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
