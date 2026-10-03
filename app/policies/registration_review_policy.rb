# Revisão de cadastros públicos; papéis institucionais não concedem este acesso.
class RegistrationReviewPolicy < ApplicationPolicy
  def menu? = active_admin?
  def index? = active_admin?
  def show? = active_admin? && reviewable?
  def approve? = show? && record.id != user.id
  def reject? = approve?

  class Scope < ApplicationPolicy::Scope
    def resolve
      active_admin? ? scope.where(deleted_at: nil).where.not(registration_role_code: nil) : scope.none
    end
  end

  private

    def reviewable?
      record.respond_to?(:registration_role_code) && record.registration_role_code.present? && record.deleted_at.nil?
    end
end
