class PresentationsController < ApplicationController
  allow_unauthenticated_access only: %i[show pdf]

  layout "presentation"

  # Usa o perfil ativo (ou ?perfil=<id>, para pré-visualizar outro perfil salvo).
  # Sem perfil salvo, vale o padrão do roteiro.yml. Esta ação só lê o banco.
  def show
    load_presentation
  end

  def pdf
    load_presentation
    choices = params[:choices]
    if choices.present?
      unless choices.is_a?(ActionController::Parameters) && choices.values.all? { |value| [ true, false ].include?(value) }
        return render json: { error: "Seleção de slides inválida." }, status: :unprocessable_content
      end

      @selection = Presentation::Selection.new(@presentation, @selection.to_h.merge(choices.permit(*@presentation.catalog_keys).to_h),
        delivery_id: @selection.delivery[:id])
    end

    html = render_to_string(:show, formats: [ :html ], layout: "presentation")
    content = Presentation::Pdf.new(html: html, theme: params[:theme],
      public_url: @presentation.entrega.dig(:links, :apresentacao)).call
    send_data content, type: "application/pdf", disposition: "attachment",
      filename: "sgu-#{@selection.delivery[:id]}-apresentacao.pdf"
  rescue Presentation::Pdf::Busy
    response.set_header("Retry-After", "10")
    render json: { error: "Já há um PDF sendo gerado. Tente novamente em alguns segundos." }, status: :service_unavailable
  rescue Presentation::Pdf::Error => error
    Rails.logger.error("Presentation PDF export failed: #{error.class}: #{error.message}")
    render json: { error: "Não foi possível gerar o PDF. Tente novamente em instantes." }, status: :service_unavailable
  end

  private

  def load_presentation
    @presentation = Presentation.load
    @profile = PresentationProfile.for_presentation(params[:perfil])
    @selection = @profile ? @profile.selection(@presentation) : @presentation.default_selection
  end
end
