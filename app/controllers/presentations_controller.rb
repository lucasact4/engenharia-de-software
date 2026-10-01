class PresentationsController < ApplicationController
  allow_unauthenticated_access only: :show

  layout "presentation"

  def show
    @presentation = Presentation.load
  end
end
