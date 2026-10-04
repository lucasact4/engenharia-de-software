# frozen_string_literal: true

# Catálogo de locais do campus para seleção manual. Começa vazio: não há dados oficiais da UFRPE
# e nenhum local é criado automaticamente. Coordenadas de referência são opcionais.
class Admin::LocationsController < Admin::BaseController
  include AdminCatalogActions

  def index
    super
    @usage = Alert.where(location_id: @instances.map(&:id)).group(:location_id).count
  end

  private

    def default_params_permited
      [ :code, :name, :description, :position, :reference_latitude, :reference_longitude, :active ]
    end
end
