require "rails_helper"

RSpec.describe "CSRF and HTTP methods", type: :request do
  let(:user) { create(:user) }
  let!(:publication) { create(:publication, :published) }

  it "rejects state changes without a CSRF token when forgery protection is on" do
    sign_in(user)
    ActionController::Base.allow_forgery_protection = true

    post publication_like_interaction_path(publication)
    post alerts_path, params: { client_request_id: SecureRandom.uuid, alert: occurrence_attributes }

    expect(PublicationLike.count).to eq(0)
    expect(Alert.count).to eq(0)
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  it "does not change state through GET" do
    sign_in(user)

    get "/mural/#{publication.id}/curtida"
    get "/painel/qualquer"

    expect(PublicationLike.count).to eq(0)
  end
end
