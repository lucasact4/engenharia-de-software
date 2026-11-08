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
    publication = create(:publication, :published, :campus_map_approved, kind: "occurrence", alert: alert)
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
    create(:publication, :published, :campus_map_approved, kind: "occurrence", alert: outside)

    reports = described_class.new(viewer: nil).call[:reports]

    expect(reports.size).to eq(1)
    expect(reports.first).to include(id: publication.id, exact: true, latitude: -8.0175, longitude: -34.9505)
  end

  it "shows only administrator-approved map posts and keeps mural approval intact" do
    alert = create(:alert, :public_request, location: location)
    publication = create(:publication, :published, kind: "occurrence", alert: alert)

    expect(described_class.new(viewer: nil).call[:spots]).to be_empty

    Publications::ApproveForCampusMap.call(actor: create(:user, :admin), publication: publication)

    expect(publication.reload).to have_attributes(review_status: "approved", visibility: "public_external")
    expect(publication).to be_approved_for_campus_map
    expect(described_class.new(viewer: nil).call[:spots].size).to eq(1)

    Alerts::UpdateContent.call(actor: alert.author, alert: alert, attributes: { description: "A ocorrência foi atualizada com novas informações." })

    expect(publication.reload).not_to be_approved_for_campus_map
    expect(described_class.new(viewer: nil).call[:spots]).to be_empty
  end

  it "splits exact reports at different points in the same building" do
    first_alert = create(:alert, :public_request, location: location, share_exact_location: true,
                                                  latitude: -8.0175, longitude: -34.9505)
    second_alert = create(:alert, :public_request, location: location, share_exact_location: true,
                                                   latitude: -8.0171, longitude: -34.9501)
    create(:publication, :published, :campus_map_approved, kind: "occurrence", alert: first_alert)
    create(:publication, :published, :campus_map_approved, kind: "occurrence", alert: second_alert)

    spots = described_class.new(viewer: nil).call[:spots]

    expect(spots.size).to eq(2)
    expect(spots.map { |spot| spot[:count] }).to eq([ 1, 1 ])
  end
end
