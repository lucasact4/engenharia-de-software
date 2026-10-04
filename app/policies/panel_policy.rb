# Painel da área autenticada: qualquer conta ativa.
class PanelPolicy < ApplicationPolicy
  def show?
    active_user?
  end
end
