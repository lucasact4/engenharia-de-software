require "rails_helper"

RSpec.describe "RF008 author follow-up journey", type: :feature, js: true do
  let(:author) { create(:user) }
  let!(:category) { create(:category, name: "Infraestrutura de teste") }
  let!(:prior) { create(:alert, :restricted, author: author, title: "Relato anterior da calçada") }

  it "relates a new occurrence, edits the reference and confirms its resolution with history" do
    sign_in_via_ui author
    visit new_alert_path
    fill_in "Título", with: "Calçada precisa de novo acompanhamento"
    fill_in "Descrição", with: "O problema da calçada continua no mesmo local."
    select "Infraestrutura de teste", from: "Categoria"
    select "#{prior.protocol} · #{prior.title}", from: "Relato anterior"
    choose "Informar o local", allow_label_click: true
    fill_in "Descrição do local", with: "Calçada em frente ao bloco de aulas"
    click_button "Publicar ocorrência"

    expect(page).to have_content("Ocorrência registrada.")
    alert = Alert.order(:id).last
    expect(alert.related_alert).to eq(prior)
    find("summary", text: "Atendimento e detalhes do registro").click
    expect(page).to have_link(prior.protocol, href: alert_path(prior, locale: I18n.locale))

    click_link "Editar relato"
    select "Nenhum relato relacionado", from: "Relato anterior"
    click_button "Salvar e atualizar publicação"
    expect(page).to have_content("Relato atualizado.")
    expect(alert.reload.related_alert).to be_nil

    accept_confirm("Você confirma que a situação desta ocorrência foi solucionada?") do
      click_button "Marcar como resolvida"
    end
    expect(page).to have_content("Ocorrência marcada como resolvida.")
    find("summary", text: "Atendimento e detalhes do registro").click
    expect(page).to have_content("Ocorrência resolvida pelo autor")
    expect(page).to have_content("Recebida → Resolvida")
    expect(page).to have_no_button("Marcar como resolvida")
    expect(alert.reload).to have_attributes(status: "resolved", resolved_at: be_present)
    page.save_screenshot(Rails.root.join("tmp/screenshots/rf008-completed.png"))
  end
end
