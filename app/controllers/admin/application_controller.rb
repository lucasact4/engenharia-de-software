# frozen_string_literal: true

# Base de toda a administração: layout, menu, Pundit e acesso restrito a users.admin.
# Não define CRUD; Admin::BaseController (genérico) e os controllers de domínio herdam daqui.
class Admin::ApplicationController < ApplicationController
  include Pagy::Method
  include Translations::TranslationFlashMessages
  include SidebarConcerns
  include Pundit::Authorization

  # A entrada administrativa não depende de cada policy: papéis como segurança e coordenação
  # nunca tornam alguém administrador. Esta checagem não marca verify_authorized.
  class AdminAreaRequired < StandardError; end

  layout "admin/base"

  rescue_from AdminAreaRequired, with: :admin_area_required

  before_action :require_admin_area
  before_action :set_pagy_locale
  before_action :set_menu # SidebarConcerns

  after_action :verify_authorized

  def pundit_user
    Current.user
  end

  private

    def require_admin_area
      raise AdminAreaRequired unless Current.user&.active? && Current.user.admin?
    end

    def admin_area_required
      respond_to do |format|
        format.html { redirect_to panel_path, alert: t("pundit.admin_area") }
        format.any { head :forbidden }
      end
    end

    def set_pagy_locale
      Pagy::I18n.locale = I18n.locale.to_s.tr("_", "-").sub(/-[a-z]{2}\z/) { |region| region.upcase }
    end
end
