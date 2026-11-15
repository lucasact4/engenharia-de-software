require "rails_helper"

RSpec.describe CampusMap::MapData, "RF010 — regras dos marcadores" do
  # Unidade: exercitamos os algoritmos internos de representação e agrupamento.
  # build_stubbed prepara objetos com IDs sem persistir dados; nenhum navegador,
  # GPS real ou API de mapas é acionado. O Rails ainda é carregado pelo helper.
  # Aprovação e acesso pelo método público call têm cobertura complementar em
  # map_data_spec.rb. Estes exemplos não comprovam essas regras de acesso.
  subject(:map_data) { described_class.new(viewer: nil) }

  let(:location) do
    build_stubbed(:location, reference_latitude: -8.017, reference_longitude: -34.95,
                            boundary: { "type" => "Polygon", "coordinates" => [ [
                              [ -34.951, -8.018 ], [ -34.949, -8.018 ], [ -34.949, -8.016 ],
                              [ -34.951, -8.016 ], [ -34.951, -8.018 ]
                            ] ] })
  end

  # As coordenadas ficam dentro do local. Cada caso altera somente os dados
  # relevantes para a regra de privacidade ou georreferenciamento em análise.
  def publication_with(**attributes)
    alert = build_stubbed(:alert, location: location, latitude: -8.0175, longitude: -34.9505,
                                  share_exact_location: false, **attributes)
    build_stubbed(:publication, kind: "occurrence", alert: alert)
  end

  # O serviço não expõe esses algoritmos como API pública. O acesso por send é
  # intencional para testar cálculo/formatação isolados, sem executar consultas.
  def marker_for(publication)
    map_data.send(:report_marker, publication, [ location ], [])
  end

  it "RF010-UT01 usa o ponto representativo quando o autor não compartilha o GPS exato" do
    publication = publication_with

    marker = marker_for(publication)

    # O GPS existe, mas o marcador deve usar o centro do local, não o ponto pessoal.
    expect(marker).to include(id: publication.id, exact: false, place_type: "location",
                              latitude: -8.017, longitude: -34.95)
    expect(marker[:google_maps_url]).to eq("https://www.google.com/maps/search/?api=1&query=-8.017,-34.95")
  end

  it "RF010-UT02 preserva o GPS exato quando autorizado e dentro do local escolhido" do
    publication = publication_with(share_exact_location: true)

    marker = marker_for(publication)

    # Consentimento e coordenadas coerentes permitem precisão, sem arredondamento.
    expect(marker).to include(exact: true, latitude: -8.0175, longitude: -34.9505)
    expect(marker[:google_maps_url]).to eq("https://www.google.com/maps/search/?api=1&query=-8.0175,-34.9505")
  end

  it "RF010-UT03 usa o local aproximado quando há consentimento mas faltam coordenadas" do
    publication = publication_with(share_exact_location: true, latitude: nil, longitude: nil)

    marker = marker_for(publication)

    # Consentimento sozinho não fornece GPS; não se deve sinalizar precisão inexistente.
    expect(marker).to include(exact: false, latitude: -8.017, longitude: -34.95)
  end

  it "RF010-UT04 não cria marcador sem coordenadas nem local georreferenciado" do
    publication = publication_with(location: nil, latitude: nil, longitude: nil,
                                   location_source: "manual", location_description: "Perto da entrada")

    marker = marker_for(publication)

    # Caracterização de uma limitação atual: descrição textual não é convertida
    # em coordenadas. Passar este caso não significa cumprir todo o RF010.
    expect(marker).to be_nil
  end

  it "RF010-UT05 usa o ponto representativo se o GPS diverge do polígono selecionado" do
    publication = publication_with(share_exact_location: true, latitude: -9.0, longitude: -35.0)

    marker = marker_for(publication)

    # Mesmo com consentimento, o ponto fora do local não deve ser publicado como exato.
    expect(marker).to include(exact: false, latitude: -8.017, longitude: -34.95)
  end

  it "RF010-UT06 agrupa dois relatos aproximados preservando a contagem e os links" do
    first = publication_with
    second = publication_with(latitude: -8.0171, longitude: -34.9501)
    markers = [ marker_for(first), marker_for(second) ]

    spot = map_data.send(:spot_marker, markers.first.fetch(:spot_key), markers)

    # Ambos pertencem ao mesmo local: o ponto agrupado preserva os dois conteúdos,
    # sem perder a localização aproximada ou inventar autorização de GPS exato.
    expect(markers.map { |marker| marker[:spot_key] }.uniq.size).to eq(1)
    expect(spot).to include(count: 2, latitude: -8.017, longitude: -34.95)
    expect(spot[:publications].map { |item| item[:id] }).to eq([ first.id, second.id ])
    expect(spot[:publications].map { |item| item[:url] }).to eq([
      Rails.application.routes.url_helpers.publication_path(first),
      Rails.application.routes.url_helpers.publication_path(second)
    ])
    expect(spot[:publications].map { |item| item[:exact] }).to eq([ false, false ])
  end
end
