class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def menu?
    false
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      scope.none
    end

    private

      def active_user?
        user.present? && user.active?
      end

      def active_admin?
        active_user? && user.admin?
      end

      def role?(code)
        active_user? && user.role?(code)
      end
  end

  private

    # Conta desativada não age nem lê como autenticada; acessa apenas o que é público.
    def active_user?
      user.present? && user.active?
    end

    def active_admin?
      active_user? && user.admin?
    end

    def role?(code)
      active_user? && user.role?(code)
    end

    # show? usa a mesma consulta do index (Scope), evitando duas regras divergentes.
    def visible_in_scope?(relation = record.class)
      return false unless record.respond_to?(:persisted?) && record.persisted?

      self.class::Scope.new(user, relation.where(id: record.id)).resolve.exists?
    end
end
