# O selo é concedido pela administração, independente da confirmação de e-mail.
class UserVerificationPolicy < ApplicationPolicy
  def update?
    active_admin? && record.active? && record.id != user.id
  end
end
