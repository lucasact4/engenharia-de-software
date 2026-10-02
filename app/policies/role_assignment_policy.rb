# Concessão e revogação de papéis (record = pessoa que recebe o papel).

class RoleAssignmentPolicy < ApplicationPolicy
  def grant?
    active_admin? && record.active? && record.id != user.id
  end

  def revoke?
    active_admin? && record.id != user.id
  end
end
