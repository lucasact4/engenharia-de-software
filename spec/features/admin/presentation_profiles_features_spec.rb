require "rails_helper"

describe "Presentation profiles in the admin", type: :feature do
  let(:admin) { create(:user, :admin, email_address: "apresentacao@example.com") }
  let!(:profile) { create(:presentation_profile, :active, name: "Segunda entrega", selections: { "gestao" => true }) }

  before { sign_in_via_ui admin }

  it "saves the selection and reflects it on the public page" do
    visit admin_presentation_profiles_path
    click_link "Apresentação"
    expect(page).to have_content("Perfil padrão da apresentação pública: Segunda entrega")

    click_link "Editar seleção"
    expect(page.find("#selection_capa")).to be_disabled
    expect(page.find("#selection_encerramento")).to be_disabled

    uncheck "Gestão e evidências"
    expect(page).to have_content("Slide oculto. As escolhas dos conteúdos ficam guardadas")
    uncheck "selection_arquitetura_mudancas"
    click_button "Salvar configurações"

    expect(page).to have_content("foi atualizado com sucesso")
    expect(profile.reload.selections).to include("gestao" => false, "arquitetura.mudancas" => false, "gestao.reunioes" => true)

    visit presentation_path
    expect(page).to have_no_css("#s-gestao", visible: true)
  end

  it "warns while editing when the estimate exceeds the delivery limit" do
    visit edit_admin_presentation_profile_path(profile)

    %w[requisitos status-report casos-de-uso fluxo-ocorrencias].each { |id| check "selection_#{id.underscore}" }

    expect(page.find("[data-presentation-profile-form-target='estimate']")).to have_text("acima do limite de 7min")
    select "Primeira Entrega dos Projetos", from: "Entrega"
    expect(page.find("[data-presentation-profile-form-target='estimate']")).to have_text("sem limite de tempo")
  end

  it "creates a profile and makes it the public default" do
    visit new_admin_presentation_profile_path
    fill_in "Nome do perfil", with: "Banca final"
    select "Primeira Entrega dos Projetos", from: "Entrega"
    check "Perfil padrão da apresentação pública"
    click_button "Salvar configurações"

    expect(page).to have_content("foi criado com sucesso")
    expect(PresentationProfile.find_by!(name: "Banca final")).to be_active
    expect(profile.reload).not_to be_active
  end
end
