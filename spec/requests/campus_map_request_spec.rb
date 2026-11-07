require "rails_helper"

RSpec.describe "Campus map", type: :request do
  it "offers a separate campus map from the mural and renders the map container" do
    get campus_map_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Mapa de ocorrências", "Mapa da UFRPE · Sede Recife",
                                     'data-controller="campus-map"', "Ainda não há publicações do mural")
    expect(response.body).not_to include("Rascunho editorial")
  end

  it "filters map publications by category, active status and reported severity" do
    category = create(:category, name: "Iluminação")
    other_category = create(:category, name: "Acessibilidade")
    location = create(:location, reference_latitude: -8.017, reference_longitude: -34.95)
    selected_alert = create(:alert, :public_request, title: "Luminária em atendimento", category: category, location: location,
                                                     latitude: -8.017, longitude: -34.95,
                                                     status: "in_progress", reported_severity: "high")
    selected = create(:publication, :published, :campus_map_approved, kind: "occurrence", alert: selected_alert)
    other_alert = create(:alert, :public_request, title: "Rampa em triagem", category: other_category, location: location,
                                                  latitude: -8.017, longitude: -34.95,
                                                  status: "triaging", reported_severity: "moderate")
    other = create(:publication, :published, :campus_map_approved, kind: "occurrence", alert: other_alert)

    get campus_map_path, params: { category_id: category.id, status: "in_progress", severity: "high" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(selected.title, category.name, "Filtrar mapa")
    expect(response.body).not_to include(other.title)
  end

  it "renders shared location previews with Leaflet and keeps the Google Maps link available" do
    alert = create(:alert, :public_request, share_exact_location: true)
    publication = create(:publication, :published, kind: "occurrence", alert: alert)

    get publication_path(publication)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-controller="location-preview"', "Abrir no Google Maps")
    expect(response.body).not_to include("output=embed")
  end
end
