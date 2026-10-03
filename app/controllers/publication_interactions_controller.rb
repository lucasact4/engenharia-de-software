# Curtir, salvar e acompanhar publicação: POST adiciona e DELETE remove (idempotentes, sem
# alternância). O tipo vem da rota, nunca do cliente; a pessoa vem da sessão.
# Remover o próprio vínculo funciona mesmo sem acesso atual e não revela a publicação.
class PublicationInteractionsController < PortalController
  KINDS = %w[like bookmark subscription].freeze
  MESSAGES = {
    "like" => [ "Você curtiu esta publicação.", "Curtida removida." ],
    "bookmark" => [ "Publicação guardada em Salvos (lista privada).", "Removida dos Salvos." ],
    "subscription" => [ "Você está acompanhando esta publicação.", "Você deixou de acompanhar esta publicação." ]
  }.freeze

  def create
    publication = PublicationPolicy::FeedScope.new(Current.user, Publication.all).resolve.find(params[:publication_id])
    authorize publication, :interact?
    Social::Interactions.add_to_publication(actor: Current.user, publication: publication, kind: kind)
    respond(publication, MESSAGES.fetch(kind).first)
  end

  def destroy
    skip_authorization # só apaga o vínculo da própria sessão (Social::Interactions.remove_from_publication)
    Social::Interactions.remove_from_publication(actor: Current.user, publication: Publication.new(id: params[:publication_id].to_i), kind: kind)
    publication = PublicationPolicy::FeedScope.new(Current.user, Publication.all).resolve.find_by(id: params[:publication_id])
    return redirect_to(fallback_path, notice: MESSAGES.fetch(kind).last, status: :see_other) if publication.nil?

    respond(publication, MESSAGES.fetch(kind).last)
  end

  private

    def kind
      value = params[:kind].to_s
      raise ActiveRecord::RecordNotFound unless KINDS.include?(value)

      value
    end

    def respond(publication, message)
      respond_to do |format|
        format.turbo_stream do
          card = PublicationProjection.collection([ publication ], viewer: Current.user).first
          render turbo_stream: turbo_stream.replace("publication_#{publication.id}_actions",
                                                    partial: "publications/actions", locals: { card: card, show_report: true })
        end
        format.html { redirect_to publication_path(publication), notice: message, status: :see_other }
      end
    end

    def fallback_path
      kind == "bookmark" ? saved_publications_path : follow_ups_path
    end
end
