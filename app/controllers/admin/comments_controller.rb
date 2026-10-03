# frozen_string_literal: true

# Moderação de comentários: remoção lógica com motivo e auditoria (Comments::Moderate).
# Respostas de outras pessoas são preservadas; o texto fica guardado para análise administrativa.
class Admin::CommentsController < Admin::ApplicationController
  include ErrorResponses

  def moderate
    comment = policy_scope(Comment).find(params[:id])
    authorize comment, :moderate?
    Comments::Moderate.call(actor: Current.user, comment: comment, reason: params[:reason])
    redirect_to return_path(comment), flash: { success: "Comentário removido da conversa." }, status: :see_other
  rescue ActiveRecord::RecordInvalid
    redirect_to return_path(comment), alert: "Informe o motivo da remoção.", status: :see_other
  end

  private

    def return_path(comment)
      Authentication.safe_return_path(params[:return_to]) || admin_publication_path(comment.publication_id)
    end

    def error_layout
      "admin/base"
    end
end
