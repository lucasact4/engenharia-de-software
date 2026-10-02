# O acesso a comentários herda a autorização atual da Publication.
class CommentPolicy < ApplicationPolicy
  def show?
    visible_in_scope?
  end

  def update?
    author? && visible_content? && publication_policy.show?
  end

  def destroy?
    update?
  end

  def like?
    active_user? && visible_content? && publication_policy.interact?
  end

  def report?
    like?
  end

  def moderate?
    active_admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if active_admin?

      scope.where(publication_id: PublicationPolicy::Scope.new(user, Publication.all).resolve.select(:id))
    end
  end

  private

    def visible_content?
      record.persisted? && Comment.visible_content.exists?(id: record.id)
    end

    def author?
      active_user? && record.author_id == user.id
    end

    def publication_policy
      PublicationPolicy.new(user, record.publication)
    end
end
