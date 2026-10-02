require "active_support/concern"

module SidebarConcerns
  extend ActiveSupport::Concern
  include Translations::TranslationsViewHelper

  included do
    def set_menu
      @menu = [
        {
          name: translate_view_application_shared("sidebar_menu.home"),
          icon: "house",
          policy: :dashboard,
          url: { controller: "dashboard", action: "index" },
          active: controller_path == "admin/dashboard"
        },
        {
          name: t("users.plural"),
          icon: "user",
          policy: :user,
          url: { controller: "users", action: "index" },
          active: controller_path == "admin/users"
        },
        {
          name: t("dogs.plural"),
          icon: "paw-print",
          policy: :dog,
          url: { controller: "dogs", action: "index" },
          active: controller_path == "admin/dogs"
        }
      ]
    end
  end
end
