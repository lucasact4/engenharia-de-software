require "active_support/concern"

module SidebarConcerns
  extend ActiveSupport::Concern
  include Translations::TranslationsViewHelper

  included do
    def set_menu
      @menu = [
        menu_item(translate_view_application_shared("sidebar_menu.home"), "house", :dashboard, "dashboard", "admin/dashboard"),
        menu_item("Ocorrências", "map-pin", Alert, "alerts", "admin/alerts"),
        menu_item("Publicações", "newspaper", Publication, "publications", "admin/publications"),
        menu_item("Denúncias", "flag", ContentReport, "content_reports", "admin/content_reports"),
        menu_item("Categorias", "tag", Category, "categories", "admin/categories"),
        menu_item("Locais", "folder", Location, "locations", "admin/locations"),
        menu_item(t("users.plural"), "user", :user, "users", "admin/users"),
        menu_item(t("presentation_profiles.menu"), "presentation", :presentation_profile, "presentation_profiles", "admin/presentation_profiles"),
        menu_item("Cadastros", "user-plus", :registration_review, "registrations", "admin/registrations")
      ]
    end

    def menu_item(name, icon, policy, controller, path)
      { name: name, icon: icon, policy: policy, url: { controller: controller, action: "index" }, active: controller_path == path }
    end
  end
end
