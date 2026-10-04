# Painel administrativo: somente administradores ativos. A área das demais pessoas é o /painel.
class DashboardPolicy < ApplicationPolicy
  def menu?
    active_admin?
  end

  def index?
    active_admin?
  end
end
