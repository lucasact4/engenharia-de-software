# Acesso operacional provisório: autor, coordenação, segurança e administração.
class AlertPolicy < ApplicationPolicy
  AUTHOR_EDITABLE_STATUSES = %w[received awaiting_information].freeze

  def index?
    active_user?
  end

  def show?
    visible_in_scope?
  end

  def create_occurrence?
    active_user?
  end

  def create_panic?
    active_user?
  end

  def update_content?
    author? && record.occurrence? && AUTHOR_EDITABLE_STATUSES.include?(record.status_in_database)
  end

  def handle?
    return false unless active_user?
    return true if active_admin?
    return true if record.occurrence? && role?(:coordination)

    role?(:security) && (record.panic? || record.assigned_to_id == user.id)
  end

  def assess?
    handle?
  end

  def transition?
    handle?
  end

  def reopen_closed?
    active_admin?
  end

  def assign?
    return true if active_admin?

    record.occurrence? ? role?(:coordination) : role?(:security)
  end

  # Fotos são mais restritas que o registro: autor e quem atende. Leitores de ocorrência
  # interna não recebem as fotos originais.
  def show_photos?
    author? || handle?
  end

  # Autor só reduz a audiência (para restricted); ampliar ou moderar é administrativo.
  def change_audience?
    record.occurrence? && (author? || active_admin?)
  end

  def expand_audience?
    record.occurrence? && active_admin?
  end

  def restrict?
    record.occurrence? && active_admin?
  end

  # Acompanhar atendimento não concede acesso e não existe para pânico.
  def subscribe?
    record.occurrence? && show?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless active_user?
      return scope.all if active_admin?

      relation = scope.where(author_id: user.id)
        .or(scope.where(kind: "occurrence", visibility: "internal"))
      relation = relation.or(scope.where(kind: "occurrence")) if role?(:coordination)
      relation = relation.or(scope.where(kind: "panic")).or(scope.where(assigned_to_id: user.id)) if role?(:security)
      relation
    end
  end

  private

    def author?
      active_user? && record.author_id == user.id
    end
end
