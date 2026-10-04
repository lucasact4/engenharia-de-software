module Social
  # Adição e remoção idempotentes; remover afeta somente os vínculos do próprio usuário.
  module Interactions
    PUBLICATION_KINDS = {
      like: PublicationLike,
      bookmark: PublicationBookmark,
      subscription: PublicationSubscription
    }.freeze

    module_function

    def add_to_publication(actor:, publication:, kind:)
      Pundit.authorize(actor, publication, :interact?)
      upsert(PUBLICATION_KINDS.fetch(kind.to_sym), user: actor, publication: publication)
    end

    def remove_from_publication(actor:, publication:, kind:)
      remove(actor, PUBLICATION_KINDS.fetch(kind.to_sym), publication: publication)
    end

    def like_comment(actor:, comment:)
      Pundit.authorize(actor, comment, :like?)
      upsert(CommentLike, user: actor, comment: comment)
    end

    def unlike_comment(actor:, comment:)
      remove(actor, CommentLike, comment: comment)
    end

    def subscribe_alert(actor:, alert:)
      Pundit.authorize(actor, alert, :subscribe?)
      upsert(AlertSubscription, user: actor, alert: alert)
    end

    def unsubscribe_alert(actor:, alert:)
      remove(actor, AlertSubscription, alert: alert)
    end

    def follow(actor:, user:)
      Pundit.authorize(actor, user, :follow?, policy_class: FollowPolicy)
      upsert(UserFollow, follower: actor, followed: user)
    end

    def unfollow(actor:, user:)
      raise Pundit::NotAuthorizedError, "conta inativa" unless actor&.active?

      UserFollow.where(follower: actor, followed: user).delete_all
      nil
    end

    # Remove os vínculos da própria pessoa cujo alvo deixou de ser acessível (retirado,
    # expirado, restrito). Não revela qual era o alvo; devolve só a quantidade removida.
    def prune_inaccessible(actor:, kind:)
      raise Pundit::NotAuthorizedError, "conta inativa" unless actor&.active?

      links, accessible = inaccessible_targets(actor, kind.to_sym)
      links.where.not(links.klass.reflect_on_association(target_name(kind.to_sym)).foreign_key => accessible).delete_all
    end

    # Em corrida, o par pode surgir como RecordNotUnique (índice) ou como erro :taken (validação).
    def upsert(model, **attributes)
      model.find_or_create_by!(**attributes)
    rescue ActiveRecord::RecordNotUnique
      model.find_by!(**attributes)
    rescue ActiveRecord::RecordInvalid => error
      raise unless error.record.errors.details.values.flatten.any? { |detail| detail[:error] == :taken }

      model.find_by!(**attributes)
    end

    def remove(actor, model, **target)
      raise Pundit::NotAuthorizedError, "conta inativa" unless actor&.active?

      model.where(user: actor, **target).delete_all
      nil
    end

    def inaccessible_targets(actor, kind)
      case kind
      when :bookmark, :subscription
        [ PUBLICATION_KINDS.fetch(kind).where(user: actor),
          PublicationPolicy::FeedScope.new(actor, Publication.all).resolve.select(:id) ]
      when :alert_subscription
        [ AlertSubscription.where(user: actor),
          AlertPolicy::Scope.new(actor, Alert.occurrence).resolve.select(:id) ]
      else
        raise ArgumentError, "vínculo sem limpeza: #{kind}"
      end
    end

    def target_name(kind)
      kind == :alert_subscription ? :alert : :publication
    end
  end
end
