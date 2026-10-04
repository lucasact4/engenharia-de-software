# frozen_string_literal: true

# Catálogo de categorias de ocorrência. Código e exigência de detalhamento ficam travados
# depois do primeiro uso (ver Category); para mudar o significado, desative e crie outra.
class Admin::CategoriesController < Admin::BaseController
  include AdminCatalogActions

  def index
    super
    @usage = Alert.where(category_id: @instances.map(&:id)).group(:category_id).count
  end

  private

    def default_params_permited
      [ :code, :name, :description, :position, :requires_details, :active ]
    end
end
