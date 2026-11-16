# Contas que podem receber o atendimento de um alerta (mesma regra de Alerts::Assign):
# ativas e administradoras, ou com papel ativo de segurança (pânico) ou coordenação/segurança.
class EligibleAssigneesQuery
  def initialize(alert)
    @alert = alert
  end

  def call
    codes = @alert.panic? ? %w[security] : %w[coordination security]
    with_role = UserRole.joins(:role).where(roles: { code: codes, active: true }).select(:user_id)

    User.active.where(admin: true).or(User.active.where(id: with_role))
      .to_a.sort_by { |user| user.display_name || user.email_address }
  end
end
