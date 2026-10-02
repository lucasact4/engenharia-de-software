# frozen_string_literal: true

# Perfis da apresentação pública (/apresentacao): cada perfil guarda a entrega e a seleção
# de slides e conteúdos do catálogo definido em config/presentation/roteiro.yml.
class Admin::PresentationProfilesController < Admin::BaseController
  before_action :set_instance_and_authorize, only: %i[ edit update destroy activate ]
  before_action :set_presentation

  def index
    @instances = policy_scope(PresentationProfile).ordered
    authorize PresentationProfile
  end

  def new
    @instance = PresentationProfile.new(
      delivery: @presentation.default_delivery[:id],
      selections: @presentation.default_selection.to_h.except(*Presentation::REQUIRED_SLIDES)
    )
    authorize @instance
  end

  def create
    @instance = PresentationProfile.new(profile_params)
    authorize @instance

    if @instance.save
      redirect_to edit_admin_presentation_profile_path(@instance), flash: { success: translate_flash("success") }
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @instance.update(profile_params)
      redirect_to edit_admin_presentation_profile_path(@instance), flash: { success: translate_flash("success") }
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @instance.destroy!
    redirect_to admin_presentation_profiles_path, flash: { success: translate_flash("success") }
  end

  def activate
    @instance.activate!
    redirect_to admin_presentation_profiles_path,
      flash: { success: "“#{@instance.name}” agora é o perfil padrão da apresentação pública." }
  end

  private

    def set_presentation
      @presentation = Presentation.load
    end

    # Os checkboxes chegam como selections[<chave do catálogo>] = "0" ou "1".
    # As chaves e os valores são validados pelo model; slides obrigatórios não vêm do formulário.
    def profile_params
      params.require(:presentation_profile).permit(:name, :description, :delivery, :active, selections: {})
    end
end
