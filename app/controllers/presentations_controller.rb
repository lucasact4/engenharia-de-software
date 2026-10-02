class PresentationsController < ApplicationController
  allow_unauthenticated_access only: :show

  layout "presentation"

  # Usa o perfil ativo (ou ?perfil=<id>, para pré-visualizar outro perfil salvo).
  # Sem perfil salvo, vale o padrão do roteiro.yml. Esta ação só lê o banco.
  def show
    @presentation = Presentation.load
    @profile = PresentationProfile.for_presentation(params[:perfil])
    @selection = @profile ? @profile.selection(@presentation) : @presentation.default_selection
  end
end
