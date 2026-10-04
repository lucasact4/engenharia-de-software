# Ações de atendimento compartilhadas pela fila (/atendimento) e pela administração.
# Cada ação autoriza a query de domínio da AlertPolicy e escreve somente pelo service.
# Erros de validação respondem 422 e conflito de versão (lock_version) responde 409; nos dois
# casos o alerta é recarregado do banco e o que a pessoa preencheu volta ao formulário.
module AlertHandlingActions
  extend ActiveSupport::Concern

  HANDLING_MESSAGES = {
    assessment: "Classificação do atendimento salva.",
    assignment: "Responsável atualizado.",
    transition: "Situação do atendimento atualizada.",
    audience: "Audiência do registro atualizada.",
    restriction: "Registro restrito e divulgação bloqueada."
  }.freeze

  def assessment
    authorize @alert, :assess?
    attributes = params.permit(:assessed_severity, :priority).to_h.transform_values(&:presence)
    run_handling(:assessment, attributes.merge(reason: params[:reason])) do
      Alerts::Assess.call(actor: Current.user, alert: @alert, attributes: attributes,
                          reason: params[:reason], lock_version: params[:lock_version])
    end
  end

  def assignment
    authorize @alert, :assign?
    run_handling(:assignment, params.permit(:assigned_to_id, :reason).to_h) do
      assignee = params[:assigned_to_id].present? ? User.find_by(id: params[:assigned_to_id]) : nil
      if params[:assigned_to_id].present? && assignee.nil?
        @alert.errors.add(:assigned_to, :not_eligible)
        raise ActiveRecord::RecordInvalid, @alert
      end
      Alerts::Assign.call(actor: Current.user, alert: @alert, assignee: assignee,
                          reason: params[:reason], lock_version: params[:lock_version])
    end
  end

  def transition
    authorize @alert, :transition?
    submitted = params.permit(:to, :reason, :closure_reason, :closure_notes, :duplicate_protocol).to_h
    run_handling(:transition, submitted) do
      Alerts::Transition.call(
        actor: Current.user, alert: @alert, to: params[:to], reason: params[:reason],
        closure_reason: params[:closure_reason], closure_notes: params[:closure_notes].presence,
        duplicate_of: duplicate_target, lock_version: params[:lock_version]
      )
    end
  end

  private

    def run_handling(form_key, submitted)
      yield
      redirect_to handling_show_path(@alert), notice: HANDLING_MESSAGES.fetch(form_key), status: :see_other
    rescue ActiveRecord::RecordInvalid, Alerts::Transition::InvalidTransition => error
      errors = @alert.errors.dup
      errors.add(:base, "Esta mudança de situação não é permitida a partir da situação atual.") if error.is_a?(Alerts::Transition::InvalidTransition)
      reload_alert
      errors.each { |item| @alert.errors.import(item) }
      @submitted = { form_key => submitted }
      render_handling_show(:unprocessable_entity)
    rescue ActiveRecord::StaleObjectError
      reload_alert
      @submitted = { form_key => submitted }
      @stale_conflict = true
      flash.now[:alert] = stale_conflict_message
      render_handling_show(:conflict)
    end

    # O alerta original de uma duplicidade é buscado pelo protocolo dentro do que a pessoa pode
    # consultar; inexistente ou inacessível recebe o mesmo erro, sem revelar nada.
    def duplicate_target
      protocol = params[:duplicate_protocol].to_s.strip.upcase
      return nil if protocol.blank? || params[:closure_reason] != "duplicate"

      target = policy_scope(Alert).where.not(id: @alert.id).find_by(protocol: protocol)
      return target if target

      @alert.errors.add(:duplicate_of, :blank)
      raise ActiveRecord::RecordInvalid, @alert
    end

    def reload_alert
      @alert = @alert.class.find(@alert.id)
    end

    def stale_conflict_message
      "Outra pessoa atualizou este alerta enquanto você preenchia o formulário. Os dados atuais foram recarregados " \
        "e o que você preencheu foi mantido. Revise e envie de novo se ainda fizer sentido."
    end
end
