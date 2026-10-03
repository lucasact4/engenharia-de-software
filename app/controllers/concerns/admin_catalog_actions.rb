# Ativação/desativação de entradas de catálogo. Não há exclusão física: entradas associadas
# continuam no histórico e aparecem como indisponíveis para novas escolhas.
module AdminCatalogActions
  extend ActiveSupport::Concern

  def activate
    toggle_active(true)
  end

  def deactivate
    toggle_active(false)
  end

  private

    def toggle_active(active)
      @instance = @model.find(params.expect(:id))
      authorize @instance, :update?
      @instance.update!(active: active)
      message = active ? "“#{@instance.name}” está ativo para novas escolhas." :
        "“#{@instance.name}” foi desativado: registros antigos continuam com ele, mas não pode ser escolhido de novo."
      redirect_to send(redirect_to_index), flash: { success: message }, status: :see_other
    end

    def filter_fields
      [ "code", "name", "description" ]
    end

    def sort_fields
      [ "position", "name", "code", "active", "created_at" ]
    end

    def default_filter_sort_column
      "position"
    end

    def default_filter_sort_direction
      "asc"
    end
end
