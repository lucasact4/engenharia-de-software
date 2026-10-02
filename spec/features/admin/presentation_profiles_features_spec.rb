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

    uncheck "selection_gestao"
    expect(page).to have_content("Slide oculto. As escolhas dos conteúdos ficam guardadas")
    uncheck "selection_arquitetura_mudancas"
    click_button "Salvar configurações"

    expect(page).to have_content("foi atualizado com sucesso")
    expect(profile.reload.selections).to include("gestao" => false, "arquitetura.mudancas" => false, "reunioes.registros" => true)

    visit presentation_path
    expect(page).to have_no_css("#s-gestao", visible: true)
  end

  it "warns while editing when the estimate exceeds the delivery limit" do
    visit edit_admin_presentation_profile_path(profile)

    %w[requisitos problema escopo casos-de-uso fluxo-ocorrencias].each { |id| check "selection_#{id.underscore}" }

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

  it "updates slide titles and requirement labels when the delivery changes" do
    visit edit_admin_presentation_profile_path(profile)
    row = page.find("li[data-slide-id='conceito-visual']")
    expect(row).to have_css("[data-slide-label]", text: "2ª entrega · Item 1")

    expect(page.all("[data-profile-group='principal'] > li").map { |entry| entry["data-slide-id"] }).to eq(%w[capa conceito-visual funcionalidades retrospectiva modelo-conceitual reunioes evolucao proximos-passos status-report encerramento])
    select "Primeira Entrega dos Projetos", from: "Entrega"
    expect(page.all("[data-profile-group='principal'] > li").map { |entry| entry["data-slide-id"] }).to eq(%w[capa requisitos arquitetura casos-de-uso gestao proximos-passos retrospectiva encerramento])

    expect(row).to have_css("label[data-slide-title]", text: "Conceito visual")
    expect(row).to have_css("[data-slide-label]", text: "Complementar")
    expect(page.find("li[data-slide-id='gestao'] [data-slide-label]")).to have_text("1ª entrega · Item 4")
  end
end
