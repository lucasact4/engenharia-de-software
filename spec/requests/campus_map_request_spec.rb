require "rails_helper"

RSpec.describe "Campus map", type: :request do
  it "offers a separate campus map from the mural and renders the map container" do
    get campus_map_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Mapa de ocorrências", "Mapa da UFRPE · Sede Recife",
                                     'data-controller="campus-map"', "Ainda não há publicações do mural")
    expect(response.body).not_to include("Rascunho editorial")
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
