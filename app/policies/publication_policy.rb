# Separa acesso editorial e leitura; verifica aprovação, validade e audiência da fonte.
class PublicationPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    visible_in_scope?
  end

  def create?
    active_admin?
  end

  def update?
    active_admin?
  end

  def submit?
    active_admin?
  end

  def review?
    active_admin?
  end

  def publish?
    active_admin?
  end

  def withdraw?
    active_admin?
  end

  # Curtir, salvar, acompanhar e denunciar exigem conta ativa e acesso atual.
  def interact?
    active_user? && show?
  end

  def comment?
    interact? && Publication.where(id: record.id, comments_enabled: true).exists?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if active_admin?

      visible = scope
        .where(state: "published", review_status: "approved")
        .where("publications.reviewed_content_version = publications.content_version")
        .where("publications.expires_at IS NULL OR publications.expires_at > ?", Time.current)

      relation = audience(visible, "public_external")
      relation = relation.or(audience(visible, "internal")) if active_user?
      relation
    end

    private

      def audience(relation, visibility)
        relation.where(visibility: visibility, alert_id: nil)
          .or(relation.where(visibility: visibility, alert_id: Publication.compatible_sources_for(visibility).select(:id)))
      end
  end
end
