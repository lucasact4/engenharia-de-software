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
    publication = create(:publication, :published, kind: "occurrence", alert: alert)

    visit campus_map_path

    expect(page).to have_css("[data-campus-map-target='map'].leaflet-container", wait: 10)
    expect(page).to have_content("1 ocorrência(s) localizada(s)")
    expect(page).not_to have_content(location.name)
    expect(page).to have_link("Abrir publicação", href: publication_path(publication))
  end

  it "loads the exact-location map instead of a blocked embedded Google frame" do
    alert = create(:alert, :public_request, share_exact_location: true)
    publication = create(:publication, :published, kind: "occurrence", alert: alert)

    visit publication_path(publication)

    expect(page).to have_css("[data-controller='location-preview'].leaflet-container", wait: 10)
    expect(page).to have_link("Abrir no Google Maps")
    expect(page).not_to have_css("iframe[title*='Google Maps']")
  end
end
