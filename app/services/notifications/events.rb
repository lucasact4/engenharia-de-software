module Notifications
  # Callbacks transacionais também cobrem todos os caminhos administrativos existentes.
  # A caixa do portal e as entregas externas são registradas juntas.
  module Events
    module_function

    def alert_created(alert)
      return unless alert.panic?

      security = User.active.joins(:roles).where(roles: { code: "security", active: true }).select(:id)
      recipients = User.active.where(admin: true).or(User.active.where(id: security))
      deliver(recipients, "panic:#{alert.id}", kind: "panic", alert: alert,
              message: "Pânico acionado · pedido #{alert.protocol}. Atenção imediata necessária.")
    end

    def alert_updated(alert)
      return unless alert.saved_change_to_status?
      return if alert.anonymous_public?

      status = I18n.t("enums.alert.status.#{alert.status}.label")
      deliver(User.active.where(id: alert.author_id), "alert:#{alert.id}:status:#{alert.lock_version}",
              kind: "alert_status", alert: alert, message: "Seu relato #{alert.protocol} mudou para #{status}.")
    end

    def publication_saved(publication)
      Nearby.publish(publication)
      if publication.review_pending? && (publication.saved_change_to_review_status? || publication.saved_change_to_content_version?)
        deliver(User.active.where(admin: true), "publication:#{publication.id}:pending:#{publication.lock_version}",
                kind: "publication_pending", publication: publication, message: "Uma postagem aguarda aprovação da administração.")
      end
      return if publication.previously_new_record?
      return if publication.alert&.anonymous_public?
      return unless publication.saved_change_to_state? || publication.saved_change_to_review_status?

      state = I18n.t("enums.publication.state.#{publication.state}.label")
      review = I18n.t("enums.publication.review_status.#{publication.review_status}.label")
      deliver(User.active.where(id: publication.author_id), "publication:#{publication.id}:status:#{publication.lock_version}",
              kind: "publication_status", publication: publication, message: "Sua postagem: #{state}; revisão: #{review}.")
    end

    def comment_created(comment)
      recipients = [ comment.publication.author_id, comment.parent&.author_id ].compact.uniq - [ comment.author_id ]
      recipients -= [ comment.publication.author_id ] if comment.publication.alert&.anonymous_public?
      deliver(User.active.where(id: recipients), "comment:#{comment.id}", kind: "comment", publication: comment.publication,
              comment: comment, message: "Um novo comentário foi publicado na sua conversa.")
    end

    def liked(like)
      comment = like.is_a?(CommentLike) ? like.comment : nil
      publication = comment ? comment.publication : like.publication
      recipient = comment ? comment.author_id : publication.author_id
      return if recipient == like.user_id
      return if publication.author_id == recipient && publication.alert&.anonymous_public?

      # Descurtir e curtir novamente não gera spam para a mesma pessoa/alvo.
      key = "like:#{comment ? 'comment' : 'publication'}:#{comment&.id || publication.id}:#{like.user_id}"
      deliver(User.active.where(id: recipient), key, kind: "like", publication: publication, comment: comment,
              message: comment ? "Seu comentário recebeu uma curtida." : "Sua postagem recebeu uma curtida.")
    end

    def report_saved(report)
      return unless report.pending? && (report.previously_new_record? || report.saved_change_to_state?)

      deliver(User.active.where(admin: true), "report:#{report.id}:pending:#{report.notification_version}",
              kind: "content_report", content_report: report, message: "Uma denúncia aguarda análise da administração.")
    end

    def deliver(recipients, key, **attributes)
      recipients.find_each do |recipient|
        # O índice único é a garantia final mesmo quando duas entregas concorrem.
        Notification.create_or_find_by!(user_id: recipient.id, event_key: key) { |record| record.assign_attributes(attributes) }
      end
    end
  end
end
