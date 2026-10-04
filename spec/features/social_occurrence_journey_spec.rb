require "rails_helper"

RSpec.describe "Student posts and public approval", type: :feature, js: true do
  let!(:category) { create(:category, name: "Infraestrutura") }
  let(:student) { create(:user, :public_profile, display_name: "Ana Campus (demonstração)") }
  let(:admin) { create(:user, :admin) }

  def capture(name, mobile: false, light: false)
    page.driver.browser.manage.window.resize_to(mobile ? 390 : 1440, mobile ? 844 : 1000)
    page.execute_script("document.documentElement.dataset.theme = arguments[0]", light ? "light" : "dark")
    page.execute_script("window.scrollTo(0, 0)")
    expect(page).to have_css("body", wait: 5) { page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth") }
    expect(page).to have_css("body", wait: 5) do
      page.evaluate_script(<<~JS)
        Array.from(document.querySelectorAll(".post-gallery-track")).every(track => {
          const position = track.scrollLeft / track.clientWidth
          return Math.abs(position - Math.round(position)) < 0.005
        })
      JS
    end
    page.save_screenshot(Rails.root.join("tmp/qa_social/#{name}.png"))
  end

  def fill_post(text, photos: false)
    visit new_alert_path
    fill_in "Título", with: "Relato sobre a biblioteca"
    choose "Informar o local", allow_label_click: true
    fill_in "Descrição", with: text
    select "Infraestrutura", from: "Categoria"
    fill_in "Descrição do local", with: "Entrada da biblioteca (demonstração)"
    select "Todos (pública)", from: "Quem pode ver"
    if photos
      file = Rails.root.join("tmp/qa_social/campus-demo.png")
      image = Vips::Image.xyz(900, 900)
      red = image[0] * 0.08 + 70
      green = image[1] * 0.1 + 100
      red.bandjoin(green).bandjoin(130).cast(:uchar).pngsave(file.to_s)
      attach_file "Fotos", [ file.to_s, file.to_s ]
      expect(page).to have_css(".photo-preview img[data-ready='true']", count: 2)
    end
  end

  before do
    FileUtils.mkdir_p(Rails.root.join("tmp/qa_social"))
    @original_window_size = page.driver.browser.manage.window.size
  end

  after do
    page.driver.browser.manage.window.resize_to(@original_window_size.width, @original_window_size.height)
  end

  it "keeps one photo post through rejection, editing, approval and anonymous reading" do
    sign_in_via_ui student
    fill_post("A iluminação da entrada da biblioteca precisa de manutenção.", photos: true)
    capture("composer-dark-desktop")
    capture("composer-dark-mobile", mobile: true)
    click_button "Publicar ocorrência"
    expect(page).to have_content("aguardando aprovação")
    alert = Alert.last
    post = alert.publication
    visit publication_path(post)
    fill_in "Seu comentário", with: "Registrado para acompanhamento."
    click_button "Comentar"
    expect(page).to have_content("Comentário publicado.")
    capture("internal-post-dark-mobile", mobile: true)
    visit publications_path
    capture("internal-feed-dark-desktop")

    Capybara.reset_sessions!
    sign_in_via_ui admin
    visit admin_publication_path(post)
    expect(page).to have_no_field("Título")
    expect(page).to have_no_field("Texto")
    capture("admin-review-dark-desktop")
    capture("admin-review-dark-mobile", mobile: true)
    fill_in "Motivo para não aprovar", with: "Retire dados pessoais e esclareça o local."
    click_button "Não aprovar"
    expect(page).to have_content("Publicação pública não aprovada")

    Capybara.reset_sessions!
    sign_in_via_ui student
    visit alert_path(alert)
    expect(page).to have_content("Retire dados pessoais e esclareça o local.")
    capture("rejection-dark-mobile", mobile: true)
    click_link "Editar relato"
    fill_in "Descrição", with: "A iluminação da biblioteca está apagada. Relato atualizado sem dados pessoais."
    click_button "Salvar e atualizar publicação"
    expect(page).to have_content("Relato atualizado.")
    expect(post.reload).to have_attributes(review_status: "pending", visibility: "internal", content_version: 2)
    expect(Publication.count).to eq(1)
    expect(post.comments.count).to eq(1)

    Capybara.reset_sessions!
    sign_in_via_ui admin
    visit admin_publication_path(post)
    click_button "Aprovar"
    expect(page).to have_content("Publicação aprovada e disponível publicamente")
    Capybara.reset_sessions!
    visit publication_path(post)
    expect(page).to have_content("Relato atualizado sem dados pessoais.")
    expect(page).to have_content("Registrado para acompanhamento.")
    expect(page).to have_css(".post-gallery-slide img", count: 2)
    find("button[aria-label='Próxima foto']").click
    expect(page).to have_css(".post-gallery-count", text: "2 / 2")
    capture("external-post-dark-desktop")
    capture("external-post-dark-mobile", mobile: true)
    capture("external-post-light-mobile", mobile: true, light: true)
    [ alert.protocol, student.email_address, "Retire dados pessoais" ].each do |private_value|
      expect(page).to have_no_content(private_value)
    end
  end

  it "publishes a verified author's post publicly without manual approval" do
    sign_in_via_ui admin
    visit admin_user_path(student)
    click_button "Conceder selo"
    expect(page).to have_content("Selo de verificado concedido.")
    capture("verified-admin-profile-desktop")
    Capybara.reset_sessions!
    sign_in_via_ui student
    fill_post("Acesso à biblioteca normalizado após a manutenção.")
    expect(page).to have_content("Você pode publicar publicamente sem aprovação.")
    click_button "Publicar ocorrência"
    expect(page).to have_content("Ocorrência registrada")
    post = Alert.last.publication
    expect(post).to have_attributes(visibility: "public_external", review_status: "approved", approval_method: "verified_author")
    visit edit_profile_path
    avatar = uploaded_photo
    attach_file "Foto de perfil", avatar.path
    click_button "Salvar perfil"
    expect(page).to have_content("Perfil atualizado.")
    expect(page).to have_css(".verified-badge")
    capture("verified-own-profile-mobile", mobile: true)
    Capybara.reset_sessions!
    visit publication_path(post)
    expect(page).to have_content("Acesso à biblioteca normalizado")
    expect(page).to have_css(".verified-badge")
    capture("verified-external-no-photo-mobile", mobile: true)
  end
end
