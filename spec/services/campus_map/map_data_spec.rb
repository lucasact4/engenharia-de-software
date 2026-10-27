require "rails_helper"

RSpec.describe CampusMap::MapData do
  let(:location) do
    create(:location, reference_latitude: -8.017, reference_longitude: -34.95,
                      boundary: { "type" => "Polygon", "coordinates" => [ [
                        [ -34.951, -8.018 ], [ -34.949, -8.018 ], [ -34.949, -8.016 ],
                        [ -34.951, -8.016 ], [ -34.951, -8.018 ]
                      ] ] })
  end

  def publish_occurrence(overrides = {})
    alert = create(:alert, :public_request, location: location, latitude: -8.0175, longitude: -34.9505, **overrides)
    publication = create(:publication, :published, kind: "occurrence", alert: alert)
    [ alert, publication ]
  end

  it "plots matched reports at the building location unless the author shared the exact point" do
    _alert, publication = publish_occurrence

    map = described_class.new(viewer: nil).call
    report = map[:reports].fetch(0)

    expect(report).to include(id: publication.id, exact: false,
                              latitude: -8.017, longitude: -34.95)
    expect(map[:locations].first).to include(boundary: location.boundary, color: described_class::BUILDING_COLORS.first)
    expect(map[:locations].first).not_to have_key(:name)
  end

  it "uses exact coordinates only after explicit sharing and ignores reports outside registered campus areas" do
    _alert, publication = publish_occurrence(share_exact_location: true)
    outside = create(:alert, :public_request, latitude: -8.02, longitude: -34.96)
    create(:publication, :published, kind: "occurrence", alert: outside)

    reports = described_class.new(viewer: nil).call[:reports]

    expect(reports.size).to eq(1)
    expect(reports.first).to include(id: publication.id, exact: true, latitude: -8.0175, longitude: -34.9505)
  end
end
