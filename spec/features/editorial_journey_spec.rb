require "rails_helper"

# Jornada 2: a administração prepara, revisa, aprova e publica; uma pessoa lê, comenta,
# responde, curte, salva e acompanha; a moderação e a retirada revogam exposição e ações.
RSpec.describe "Editorial journey", type: :feature, js: true do
  let(:admin) { create(:user, :admin, email_address: "editora@example.com") }
  let(:reader) { create(:user, :public_profile, display_name: "Leitora Demonstração") }
  let(:other_reader) { create(:user, display_name: "Outra Pessoa") }

  it "goes from draft to publication, social interaction, moderation and withdrawal" do
    sign_in_via_ui admin
    visit new_admin_publication_path
    choose "Notícia"
    fill_in "Título", with: "Restaurante universitário com novo horário"
    fill_in "Texto", with: "A partir de segunda-feira o restaurante abre às 11h e fecha às 14h30."
    click_button "Criar rascunho"
    expect(page).to have_content("Rascunho criado")

    click_button "Enviar para revisão"
    click_button "Aprovar"
    expect(page).to have_content("Versão aprovada. Ela ainda não está no ar")
    click_button "Publicar agora"
    expect(page).to have_content("Publicação no ar")
    publication = Publication.last

    Capybara.reset_sessions!
    visit publication_path(publication)
    expect(page).to have_content("Restaurante universitário com novo horário")
    expect(page).to have_link("Entre para interagir")

    sign_in_via_ui other_reader
    visit publication_path(publication)
    fill_in "Seu comentário", with: "Ótima notícia para quem estuda à tarde!"
    click_button "Comentar"
    expect(page).to have_content("Comentário publicado.")
    root = Comment.last

    Capybara.reset_sessions!
    sign_in_via_ui reader
    visit publication_path(publication)
    within("#comment_#{root.id}") do
      find("summary", text: "Responder").click
      fill_in "Sua resposta", with: "Concordo, ajuda muito."
      click_button "Responder"
    end
    expect(page).to have_content("Concordo, ajuda muito.")

    within("#publication_#{publication.id}_actions") do
      click_button "Curtir"
      expect(page).to have_button("Curtido")
      click_button "Salvar"
      expect(page).to have_button("Salvo")
      click_button "Acompanhar"
      expect(page).to have_button("Acompanhando")
    end
    expect(PublicationLike.where(user: reader).count).to eq(1)

    visit saved_publications_path
    expect(page).to have_content("Restaurante universitário com novo horário")

    Capybara.reset_sessions!
    sign_in_via_ui admin
    visit admin_publication_path(publication)
    within("#admin_comment_#{root.id}") do
      fill_in "Motivo da remoção", with: "Teste de moderação"
      accept_confirm { click_button "Remover" }
    end
    expect(page).to have_content("Comentário removido da conversa.")
    fill_in "withdraw_reason", with: "Horário alterado novamente"
    accept_confirm { click_button "Retirar" }
    expect(page).to have_content("Publicação retirada do ar.")

    Capybara.reset_sessions!
    sign_in_via_ui reader
    visit publication_path(publication)
    expect(page).to have_content("Conteúdo não encontrado")
    visit saved_publications_path
    expect(page).to have_no_content("Restaurante universitário com novo horário")
    expect(page).to have_content("não está mais disponível")
    click_button "Remover indisponíveis"
    expect(page).to have_content("1 vínculo(s) indisponível(is) removido(s).")
  end
end
