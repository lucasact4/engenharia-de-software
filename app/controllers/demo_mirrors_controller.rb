# Demonstração ao vivo: o SGU no computador e no celular, espelhados nos dois sentidos, com o roteiro ao lado.
# A página só monta dois iframes do próprio SGU; quem está logado continua sendo quem usa o navegador.
# ?embed=1 é usado pela apresentação, que abre esta página por cima dos slides sem sair da tela cheia.
class DemoMirrorsController < ApplicationController
  allow_unauthenticated_access

  layout "presentation"

  SHORTCUTS = [
    [ "Início", "/" ],
    [ "Mural", "/mural" ],
    [ "Mapa", "/mural/mapa" ],
    [ "Registrar", "/alertas/new" ],
    [ "Acompanhar", "/acompanhamentos" ],
    [ "Pânico", "/panico" ],
    [ "Atendimento", "/atendimento" ]
  ].freeze

  def show
    paths = SHORTCUTS.map(&:last)
    @start = paths.include?(params[:inicio]) ? params[:inicio] : "/"
    @embedded = params[:embed] == "1"
    @shortcuts = SHORTCUTS
    @steps = Presentation.load.entrega_final.dig(:demo, :passos) || []
  end
end
