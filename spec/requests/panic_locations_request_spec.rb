require "rails_helper"

RSpec.describe "Localização contínua do pânico", type: :request do
  let(:author) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:panic) { create(:alert, :panic, author: author, location_source: "gps", latitude: -8, longitude: -34.9) }
  let(:point) { { latitude: -8.01, longitude: -34.91, captured_at: (Time.current.to_f * 1000).to_i } }

  it "stores only the newest point and leaves the original location intact" do
    sign_in(author)
    patch panic_location_path(panic), params: point, as: :json
    expect(response).to have_http_status(:no_content)
    patch panic_location_path(panic), params: point.merge(latitude: 0, captured_at: point[:captured_at] - 1), as: :json
    get panic_location_path(panic), as: :json
    expect(response.parsed_body.fetch("position")).to eq(point.stringify_keys)
    expect(panic.reload.latitude).to eq(-8)
  end

  [:author, :admin].each do |actor|
    it "allows the #{actor} to end tracking and records who did it" do
      user = public_send(actor)
      sign_in(user)
      panic.update!(panic_latest_position: point.stringify_keys)
      delete panic_location_path(panic)
      expect(response).to have_http_status(:see_other)
      expect(AuditEvent.for_subject(panic).exists?(action: "alert.panic_tracking_stopped", actor: user)).to be(true)
      expect(panic.reload.panic_latest_position).to be_nil
      sign_in(author)
      get panic_location_path(panic), as: :json
      expect(response.parsed_body).to include("stopped" => true, "source" => nil, "position" => nil)
      expect(panic.reload).to have_attributes(latitude: nil, longitude: nil, location_source: "unavailable")
      patch panic_location_path(panic), params: point, as: :json
      expect(response).to have_http_status(:gone)
    end
  end

  it "uses the initial location when updates become stale and clears the live point on resolution" do
    sign_in(author)
    patch panic_location_path(panic), params: point, as: :json
    travel 31.seconds do
      get panic_location_path(panic), as: :json
      expect(response.parsed_body).to include("source" => "initial", "stopped" => false)
    end

    %w[triaging in_progress resolved].each do |status|
      Alerts::Transition.call(actor: admin, alert: panic.reload, to: status)
    end
    expect(panic.reload.panic_latest_position).to be_nil
    expect(panic).to be_panic_tracking_stopped
    expect(panic).to have_attributes(latitude: nil, longitude: nil)
  end

  it "keeps coordinates private and does not accept updates for ordinary alerts" do
    sign_in(create(:user))
    get panic_location_path(panic), as: :json
    expect(response).to have_http_status(:not_found)

    sign_in(author)
    occurrence = create(:alert, author: author)
    patch panic_location_path(occurrence), params: point, as: :json
    expect(response).to have_http_status(:not_found)
  end
end
