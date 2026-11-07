require "rails_helper"

RSpec.describe "Campus map for the community", type: :feature, js: true do
  let(:location) do
    create(:location, name: "Bloco de teste", reference_latitude: -8.017, reference_longitude: -34.95,
                      boundary: { "type" => "Polygon", "coordinates" => [ [
                        [ -34.951, -8.018 ], [ -34.949, -8.018 ], [ -34.949, -8.016 ],
                        [ -34.951, -8.016 ], [ -34.951, -8.018 ]
                      ] ] })
  end

  it "loads the campus map and links its report marker to the mural post" do
    alert = create(:alert, :public_request, location: location, latitude: -8.0175, longitude: -34.9505)
    publication = create(:publication, :published, :campus_map_approved, kind: "occurrence", alert: alert)

    visit campus_map_path

    expect(page).to have_css("[data-campus-map-target='map'].leaflet-container", wait: 10)
    expect(page).to have_content("1 ocorrência(s) localizada(s)")
    expect(page).not_to have_content(location.name)
    expect(page).to have_link("Abrir publicação", href: publication_path(publication))
  end

  it "clusters nearby spots when zoomed out and separates them when zoomed in" do
    original_size = page.driver.browser.manage.window.size
    page.driver.browser.manage.window.resize_to(1440, 1000)
    locations = [ -34.9505, -34.95 ].map.with_index do |longitude, index|
      latitude = -8.0175
      half_size = 0.00005
      ring = [
        [ longitude - half_size, latitude - half_size ], [ longitude + half_size, latitude - half_size ],
        [ longitude + half_size, latitude + half_size ], [ longitude - half_size, latitude + half_size ],
        [ longitude - half_size, latitude - half_size ]
      ]
      create(:location, name: "Ponto #{index + 1}", reference_latitude: latitude, reference_longitude: longitude,
                        boundary: { "type" => "Polygon", "coordinates" => [ ring ] })
    end
    locations.each_with_index do |campus_location, index|
      alert = create(:alert, :public_request, location: campus_location,
                                              latitude: campus_location.reference_latitude,
                                              longitude: campus_location.reference_longitude)
      create(:publication, :published, :campus_map_approved, kind: "occurrence", alert: alert, title: "Ocorrência #{index + 1}")
    end

    visit campus_map_path
    expect(page).to have_css("[data-campus-map-target='map'].leaflet-container", wait: 10)
    expect(page).to have_content("2 publicação(ões) ativa(s)")
    zoom = page.driver.browser.execute_async_script(<<~JS)
      const done = arguments[arguments.length - 1]
      const element = document.querySelector('[data-controller~="campus-map"]')
      const map = window.Stimulus.getControllerForElementAndIdentifier(element, "campus-map").map
      requestAnimationFrame(() => requestAnimationFrame(() => {
        map.stop()
        map.setZoom(13, { animate: false })
        requestAnimationFrame(() => done(map.getZoom()))
      }))
    JS
    expect(zoom).to eq(13)
    expect(page).to have_css(".campus-map-cluster", text: "2")

    find(".campus-map-cluster").click
    page.execute_script(<<~JS)
      const element = document.querySelector('[data-controller~="campus-map"]')
      const map = window.Stimulus.getControllerForElementAndIdentifier(element, "campus-map").map
      map.stop()
      map.setZoom(18, { animate: false })
    JS
    expect(page).to have_css(".leaflet-marker-icon.campus-map-spot", count: 2)
    expect(page).to have_no_css(".campus-map-cluster")
  ensure
    page.driver.browser.manage.window.resize_to(original_size.width, original_size.height) if original_size
  end

  it "keeps the campus map within a small viewport" do
    original_size = page.driver.browser.manage.window.size
    page.driver.browser.manage.window.resize_to(390, 844)

    visit campus_map_path

    expect(page).to have_css("[data-campus-map-target='map'].leaflet-container", wait: 10)
    expect(page).to have_select("category_id")
    expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
  ensure
    page.driver.browser.manage.window.resize_to(original_size.width, original_size.height) if original_size
  end

  it "loads the exact-location map instead of a blocked embedded Google frame" do
    alert = create(:alert, :public_request, share_exact_location: true)
    publication = create(:publication, :published, kind: "occurrence", alert: alert)

    visit publication_path(publication)

    expect(page).to have_button("Mostrar Localização")
    expect(page).to have_no_css("[data-controller='location-preview'].leaflet-container")
    click_button "Mostrar Localização"
    expect(page).to have_button("Ocultar Localização")
    expect(page).to have_css("[data-controller='location-preview'].leaflet-container", wait: 10)
    expect(page).to have_link("Abrir no Google Maps")
    expect(page).not_to have_css("iframe[title*='Google Maps']")

    click_button "Ocultar Localização"
    expect(page).to have_button("Mostrar Localização")
    expect(page).to have_no_css("[data-controller='location-preview'].leaflet-container")
  end
end
