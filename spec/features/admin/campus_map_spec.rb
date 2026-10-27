require "rails_helper"

RSpec.describe "Campus map administration", type: :feature, js: true do
  let(:admin) { create(:user, :admin) }

  before { sign_in_via_ui(admin) }

  it "draws and saves a building outline from map clicks" do
    visit new_admin_location_path
    expect(page).to have_css("[data-campus-boundary-target='map'].leaflet-container", wait: 10)

    click_button "Desenhar área"
    click_map_point(80, 80)
    expect(page).to have_content("1 ponto(s) marcado(s)")
    click_map_point(180, 80)
    expect(page).to have_content("2 ponto(s) marcado(s)")
    click_map_point(300, 200)
    expect(page).to have_content("3 ponto(s) marcado(s)")
    click_button "Finalizar contorno"
    expect(page).to have_content("Contorno finalizado")

    fill_in "Nome", with: "Prédio desenhado"
    fill_in "Código estável", with: "predio_desenhado"
    click_button "Salvar local"
    expect(page).to have_no_css("form#new_location")

    boundary = Location.find_by!(code: "predio_desenhado").boundary
    expect(boundary.fetch("type")).to eq("Polygon")
    expect(boundary.dig("coordinates", 0).length).to eq(4)
  end

  it "lets administrators adjust vertices of a saved building outline" do
    location = create(:location, boundary: {
      "type" => "Polygon", "coordinates" => [ [
        [ -34.951, -8.018 ], [ -34.949, -8.018 ], [ -34.949, -8.016 ],
        [ -34.951, -8.016 ], [ -34.951, -8.018 ]
      ] ]
    })

    visit edit_admin_location_path(location)
    click_button "Ajustar vértices"

    expect(page).to have_css(".boundary-edit-handle", count: 4)
    expect(page).to have_content("Arraste os pontos brancos para ajustar o contorno")
  end

  def click_map_point(x, y)
    page.execute_script(<<~JS, x, y)
      const map = document.querySelector('[data-campus-boundary-target="map"]');
      const rect = map.getBoundingClientRect();
      map.dispatchEvent(new MouseEvent("click", { bubbles: true, clientX: rect.left + arguments[0], clientY: rect.top + arguments[1] }));
    JS
  end
end
