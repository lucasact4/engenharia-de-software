require "rails_helper"

RSpec.describe "Occurrence composer controls", type: :feature, js: true do
  let(:author) { create(:user) }
  let!(:category) { create(:category, code: "infrastructure", name: "Infraestrutura", description: "Prédios e iluminação.") }

  before do
    @original_window_size = page.driver.browser.manage.window.size
    sign_in_via_ui author
  end

  after { page.driver.browser.manage.window.resize_to(@original_window_size.width, @original_window_size.height) }

  def fill_text
    fill_in "Título", with: "Poste apagado na biblioteca"
    fill_in "Descrição", with: "O poste da entrada da biblioteca está apagado há duas noites."
    select "Infraestrutura", from: "Categoria"
  end

  def capture(name, mobile: false, light: false)
    FileUtils.mkdir_p(Rails.root.join("tmp/qa_composer"))
    page.driver.browser.manage.window.resize_to(mobile ? 390 : 1440, mobile ? 844 : 1100)
    page.execute_script("document.documentElement.dataset.theme = arguments[0]", light ? "light" : "dark")
    expect(page).to have_css("body", wait: 5) { page.evaluate_script("document.documentElement.scrollWidth <= innerWidth") }
    if name.start_with?("composer-map")
      page.execute_script("document.querySelector('.composer-map').scrollIntoView({ block: 'center' })")
      expect(page).to have_css(".occurrence-map-pin") do |pin|
        page.evaluate_script("(() => { const p = arguments[0].getBoundingClientRect(), m = document.querySelector('.composer-map').getBoundingClientRect(); return p.left >= m.left && p.right <= m.right && p.top >= m.top && p.bottom <= m.bottom })()", pin.native)
      end
    end
    page.save_screenshot(Rails.root.join("tmp/qa_composer/#{name}.png"))
  end

  it "creates a post with explicit title, visible severity and an editable photo cover" do
    visit new_alert_path
    fill_text
    choose "Informar o local", allow_label_click: true
    fill_in "Descrição do local", with: "Entrada da biblioteca"
    choose "Alta", allow_label_click: true
    photo = uploaded_photo
    attach_file "Fotos", [ photo.path, photo.path ]
    expect(page).to have_css(".photo-editor-card img[data-ready='true']", count: 2)
    find("button[aria-label='Usar foto 2 como capa']").click
    expect(page).to have_content("Capa atualizada")
    capture("composer-desktop")
    capture("composer-mobile", mobile: true)
    capture("composer-light-mobile", mobile: true, light: true)
    click_button "Publicar ocorrência"
    expect(page).to have_content("Ocorrência registrada")
    alert = Alert.last
    expect(alert).to have_attributes(title: "Poste apagado na biblioteca", reported_severity: "high")
    expect(alert.photos.count).to eq(2)
    visit edit_alert_path(alert)
    expect(page).to have_css(".photo-editor-card", count: 2)
    ids = alert.ordered_photos.map(&:id)
    find("button[aria-label='Usar foto 2 como capa']").click
    click_button "Salvar e atualizar publicação"
    expect(page).to have_content("Relato atualizado.")
    expect(alert.reload.ordered_photos.map(&:id)).to eq(ids.reverse)
    visit edit_alert_path(alert)
    find("button[aria-label='Remover foto 2']").click
    expect(page).to have_css(".photo-editor-card", count: 1)
    expect(alert.reload.photos.count).to eq(2)
    click_button "Salvar e atualizar publicação"
    expect(page).to have_content("Relato atualizado.")
    expect(alert.reload.photos.count).to eq(1)
    expect(alert.photos.first.blob.download).to start_with("\x89PNG".b)
  end

  it "selects a real point on the embedded map, imports a Google Maps link and preserves an optional campus location" do
    location = create(:location, name: "Local de demonstração")
    visit new_alert_path
    fill_text
    select location.name, from: "Local do campus"
    choose "Marcar no mapa", allow_label_click: true
    expect(page).to have_css(".leaflet-container")
    find(".composer-map").click(x: 170, y: 100)
    expect(page).to have_content("Ponto selecionado no mapa")
    expect(find("#alert_latitude", visible: false).value).not_to be_empty
    fill_in "Link do Google Maps", with: "https://www.google.com/maps/search/?api=1&query=-8.0171234,-34.9501234"
    click_button "Usar ponto do link"
    expect(page).to have_field("Latitude", with: "-8.0171234")
    expect(page).to have_field("Longitude", with: "-34.9501234")
    fill_in "Latitude", with: ""
    find("label", text: "Longitude", exact_text: true).click
    expect(find("#alert_latitude", visible: false).value).to eq("")
    expect(page).to have_no_css(".occurrence-map-pin")
    choose "Usar GPS", allow_label_click: true
    expect(page).to have_css("[data-geolocation-target='mapLatitude'][disabled]", visible: :all)
    choose "Marcar no mapa", allow_label_click: true
    click_button "Usar ponto do link"
    capture("composer-map-desktop")
    capture("composer-map-mobile", mobile: true)
    click_button "Publicar ocorrência"
    expect(page).to have_content("Ocorrência registrada")
    expect(Alert.last).to have_attributes(location_source: "map", location: location, location_accuracy_meters: nil, location_captured_at: nil)
  end

  it "shows category examples without overflowing the mobile viewport and rejects unsupported map links" do
    visit new_alert_path
    desktop_button = find("button[aria-label='Categorias e exemplos de uso']")
    desktop_button.hover
    expect(page).to have_css(".sgu-tooltip[data-visible='true'] .sgu-tooltip-content")
    find(".sgu-tooltip[data-visible='true'] .sgu-tooltip-content").hover
    expect(page).to have_css(".sgu-tooltip[data-visible='true']", text: "Lâmpada apagada")
    desktop_button.send_keys(:escape)
    page.driver.browser.manage.window.resize_to(390, 844)
    button = find("button[aria-label='Categorias e exemplos de uso']")
    button.click
    expect(page).to have_css(".sgu-tooltip[data-visible='true']", text: "Lâmpada apagada")
    tooltip = find(".sgu-tooltip[data-visible='true'] .sgu-tooltip-content")
    expect(page.evaluate_script("arguments[0].getBoundingClientRect().right <= innerWidth", tooltip.native)).to be(true)
    capture("category-help-mobile", mobile: true)
    button.send_keys(:escape)
    expect(page).to have_no_css(".sgu-tooltip[data-visible='true']")
    choose "Marcar no mapa", allow_label_click: true
    fill_in "Link do Google Maps", with: "https://example.com/maps/@-8,-34"
    click_button "Usar ponto do link"
    expect(page).to have_content("Use um link completo do Google Maps")
    expect(find("#alert_latitude", visible: false).value).to eq("")
  end
end
