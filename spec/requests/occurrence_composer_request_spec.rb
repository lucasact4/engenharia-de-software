require "rails_helper"

RSpec.describe "Flexible occurrence location and photos", type: :request do
  let(:author) { create(:user) }
  let(:location) { create(:location) }

  before { sign_in(author) }

  it "keeps a campus location together with captured GPS and explicit title" do
    post alerts_path, params: { alert: occurrence_attributes(title: "Título escrito pelo estudante", location_source: "gps", location_id: location.id,
      location_description: "Entrada lateral", location_accuracy_meters: 12, location_captured_at: Time.current.iso8601) }
    expect(response).to have_http_status(:see_other)
    expect(Alert.last).to have_attributes(title: "Título escrito pelo estudante", location: location, location_source: "gps", location_description: "Entrada lateral")
  end

  it "accepts a map point with an optional catalog entry but clears forged GPS metadata" do
    post alerts_path, params: { alert: occurrence_attributes(location_source: "map", location_id: location.id, location_accuracy_meters: 2, location_captured_at: Time.current.iso8601) }
    expect(response).to have_http_status(:see_other)
    expect(Alert.last).to have_attributes(location_source: "map", location: location, location_accuracy_meters: nil, location_captured_at: nil)
  end

  it "requires a coordinate pair and valid ranges for map points" do
    [ { longitude: nil }, { latitude: 91 }, { longitude: 181 } ].each do |invalid|
      post alerts_path, params: { alert: occurrence_attributes(location_source: "map", **invalid) }
      expect(response).to have_http_status(:unprocessable_entity)
    end
    expect(Alert.count).to eq(0)
  end

  it "rejects an explicitly empty title even when the description is valid" do
    post alerts_path, params: { alert: occurrence_attributes(title: "") }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(Alert.count).to eq(0)
  end

  it "only reveals map coordinates to operational readers" do
    post alerts_path, params: { alert: occurrence_attributes(location_source: "map", latitude: -8.1234567, longitude: -34.9876543, requested_visibility: "internal") }
    alert = Alert.last
    get publication_path(alert.publication)
    expect(response.body).not_to include("-8.1234567", "-34.9876543")
    detail = AlertDetailPresenter.new(alert, viewer: author)
    expect(detail.coordinates[:latitude]).to eq(BigDecimal("-8.1234567"))
  end
end
