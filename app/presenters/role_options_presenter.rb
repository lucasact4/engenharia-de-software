# Papéis selecionáveis; conceder um papel não torna a pessoa administradora.
class RoleOptionsPresenter
  def initialize(actor:, user:)
    @actor = actor
    @user = user
  end

  def options
    return [] unless RoleAssignmentPolicy.new(@actor, @user).grant?

    granted = @user.roles.pluck(:code)
    roles = Role.where(code: Role::RECOGNIZED_CODES).merge(Role.active.or(Role.where(code: granted))).ordered
    roles.map do |role|
      SelectOption.from_catalog(role, value: role.code).to_h.merge(selected: granted.include?(role.code))
    end
  end
end
