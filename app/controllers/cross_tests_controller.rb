# Testes cruzados do MVP: recomendações para a equipe testadora e plano de teste (com PDF).
class CrossTestsController < ApplicationController
  allow_unauthenticated_access

  layout "presentation"

  before_action :load_content

  def show
  end

  def plan
  end

  def plan_pdf
    html = render_to_string(:plan, formats: [ :html ], layout: "presentation")
    content = Presentation::Pdf.new(html: html, theme: "light", public_url: @testing.mvp[:url], layout: :document).call
    send_data content, type: "application/pdf", disposition: "attachment", filename: "sgu-plano-de-teste.pdf"
  rescue Presentation::Pdf::Busy
    redirect_to test_plan_path(locale: nil), alert: "Já há um PDF sendo gerado. Tente novamente em alguns segundos."
  rescue Presentation::Pdf::Error => error
    Rails.logger.error("Test plan PDF export failed: #{error.class}: #{error.message}")
    redirect_to test_plan_path(locale: nil), alert: "Não foi possível gerar o PDF. Tente novamente em instantes."
  end

  private

  def load_content
    @testing = Presentation::CrossTesting.load
    presentation = Presentation.load
    @entrega = presentation.entrega
    @requirements_doc = presentation.requisitos[:documento]
  end
end
