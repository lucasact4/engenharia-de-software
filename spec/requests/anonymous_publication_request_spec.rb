require "rails_helper"

RSpec.describe "Anonymous public occurrence identity", type: :request do
  let(:author) { create(:user, :public_profile) }
  let(:category) { create(:category) }

  before { sign_in(author) }

  def submit_anonymous_occurrence(token)
    post alerts_path, params: {
      client_request_id: SecureRandom.uuid,
      cf_turnstile_response: token,
      alert: {
        title: "Lâmpada queimada no bloco",
        description: "Corredor do primeiro andar sem iluminação desde ontem.",
        category_id: category.id,
        location_source: "gps",
        latitude: "-8.0171234",
        longitude: "-34.9501234",
        location_accuracy_meters: "12",
        location_captured_at: 1.minute.ago.iso8601,
        requested_visibility: "public_external",
        anonymous_public: "1"
      }
    }
  end

  it "rejects the request when Turnstile verification fails" do
    allow(TurnstileVerifier).to receive(:configured?).and_return(true)
    allow(TurnstileVerifier).to receive(:verify).and_return(false)

    expect { submit_anonymous_occurrence("invalid-token") }.not_to change(Alert, :count)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Não foi possível confirmar o desafio antirobô")
  end

  it "keeps the account responsible while hiding its public identity" do
    author.update!(verified_at: Time.current)
    allow(TurnstileVerifier).to receive(:verify).and_return(true)

    expect { submit_anonymous_occurrence("valid-token") }.to change(Alert, :count).by(1)

    alert = Alert.last
    expect(alert.author).to eq(author)
    expect(alert).to be_anonymous_public
    expect(alert.publication).to be_public_external

    public_card = PublicationProjection.new(alert.publication, viewer: nil).as_json
    expect(public_card[:author]).to include(display_name: "Pessoa anônima", public_profile: false, id: nil, verified: false)

    responsible_card = PublicationProjection.new(alert.publication, viewer: author).as_json
    expect(responsible_card[:author][:display_name]).to eq(author.display_name)

    reader = create(:user)
    reader_card = PublicationProjection.new(alert.publication, viewer: reader).as_json
    expect(reader_card[:author]).to include(display_name: "Pessoa anônima", public_profile: false, id: nil, verified: false)

    admin = create(:user, :admin)
    admin_card = PublicationProjection.new(alert.publication, viewer: admin).as_json
    expect(admin_card[:author][:display_name]).to eq(author.display_name)
  end
end