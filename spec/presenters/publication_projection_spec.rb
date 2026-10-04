require "rails_helper"

RSpec.describe PublicationProjection do
  let(:alert) { create(:alert, :public_request, description: "Descrição operacional privada", latitude: -8.1234567, longitude: -34.7654321) }
  let(:publication) { create(:publication, :published, kind: "occurrence", alert: alert) }

  it "uses an allowlist without operational author, alert, GPS, reports or audit" do
    ContentReport.create!(reporter: create(:user), publication: publication, reason: "spam")
    json = described_class.new(publication).as_json

    expect(json.keys).to eq(%i[id kind kind_label title body visibility published_at expires_at comments_enabled
                               editorial_identity author photos own_review likes_count comments_count viewer_state])
    expect(json[:body]).to eq(alert.description)
    expect(json[:own_review]).to be_nil
    serialized = json.to_json
    [ alert.author.email_address, alert.protocol, "-8.1234567", "-34.7654321",
      publication.author.email_address, "alert_id", "spam", "admin" ].each do |secret|
      expect(serialized).not_to include(secret)
    end
  end

  it "refuses to project content the viewer cannot see" do
    expect { described_class.new(create(:publication)).as_json }.to raise_error(Pundit::NotAuthorizedError)
  end
end
