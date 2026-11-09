# Separa acesso editorial e leitura; verifica aprovação, validade e audiência da fonte.
class PublicationPolicy < ApplicationPolicy
  def menu?
    active_admin?
  end

  def index?
    true
  end

  # Gestão editorial (listas e detalhes administrativos, inclusive rascunhos).
  def manage?
    active_admin?
  end

  def show?
    visible_in_scope?
  end

  def create?
    active_admin?
  end

  def update?
    active_admin? && !record.occurrence? && !record.withdrawn? && !record.moderation_blocked?
  end

  def submit?
    active_admin? && !record.occurrence? && !record.withdrawn? && !record.moderation_blocked?
  end

  def review?
    active_admin? && !record.withdrawn? && !record.moderation_blocked? &&
      (!record.occurrence? || (record.alert.requested_public_external? && !record.alert.publication_blocked?))
  end

  def approve_for_campus_map?
    active_admin? && record.occurrence? && record.published? && !record.withdrawn? && !record.moderation_blocked? &&
      record.public_external? &&
      record.approved_for_current_content? && record.alert.requested_public_external? &&
      !record.alert.publication_blocked? && !record.approved_for_campus_map? &&
      record.alert.status.in?(%w[received triaging in_progress awaiting_information])
  end

  def publish?
    active_admin? && !record.occurrence? && !record.withdrawn? && !record.moderation_blocked?
  end

  def withdraw?
    active_admin?
  end

  def destroy?
    active_admin? && !record.withdrawn?
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

      FeedScope.new(user, scope).resolve
    end
  end

  # Restringe a busca por criador às identidades exibidas pela projeção do mural.
  class AuthorIdentityScope < ApplicationPolicy::Scope
    def resolve
      occurrences = scope.occurrence.where(author_id: User.active.select(:id))
      identified = occurrences.where(visibility: "internal")
        .or(occurrences.where(author_id: User.active.where(public_profile: true).select(:id)))
      return identified if active_admin? || role?(:coordination)

      visible = identified.where(alert_id: Alert.occurrence.where(anonymous_public: false).select(:id))
      return visible unless active_user?

      visible = visible.or(identified.where(author_id: user.id))
      visible = visible.or(identified.where(alert_id: Alert.where(assigned_to_id: user.id).select(:id))) if role?(:security)
      visible
    end
  end

  # O que está no ar para quem lê, inclusive para administradores (rascunhos ficam no admin).
  class FeedScope < ApplicationPolicy::Scope
    def resolve
      visible = scope
        .where(state: "published", moderation_blocked: false)
        .where("(publications.kind = 'occurrence' AND publications.visibility = 'internal') OR (publications.review_status = 'approved' AND publications.reviewed_content_version = publications.content_version)")
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
