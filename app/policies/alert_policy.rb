# Acesso operacional provisório: autor, coordenação, segurança e administração.
class AlertPolicy < ApplicationPolicy
  AUTHOR_EDITABLE_STATUSES = %w[received awaiting_information].freeze

  def menu?
    active_admin?
  end

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

  # Correção administrativa do texto/categoria de outra pessoa: auditada, com motivo, e sem
  # tocar localização, severidade relatada ou fotos (evidência do relato original).
  def correct_content?
    active_admin? && record.occurrence? && record.status_in_database != "closed"
  end

  # Remoção individual de foto: o autor enquanto pode editar; o administrador por correção.
  def remove_photo?
    update_content? || correct_content?
  end

  # Fila de atendimento (/atendimento): admin, coordenação ou segurança. Record é a classe.
  def queue?
    active_admin? || role?(:coordination) || role?(:security)
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

  # Coordenadas GPS, autoria e notas de encerramento seguem a mesma regra das fotos.
  def show_operational_details?
    show_photos?
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

  # Fila de atendimento: somente o que a pessoa pode atender (mesma regra de handle?).
  class HandlingScope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless active_user?
      return scope.all if active_admin?

      relation = scope.none
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
