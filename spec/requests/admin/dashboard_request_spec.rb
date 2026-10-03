require "rails_helper"

RSpec.describe "Admin dashboard", type: :request do
  it "allows an active admin" do
    sign_in(create(:user, :admin))

    get admin_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Pede ação")
  end

  it "sends a regular user to their own panel instead of the administration" do
    sign_in(create(:user))

    get admin_path

    expect(response).to redirect_to(panel_path(locale: I18n.default_locale))
  end

  it "keeps security and coordination roles out of the administration" do
    user = create(:user)
    grant_role(user, :security)
    grant_role(user, :coordination)
    sign_in(user)

    get admin_path
    expect(response).to redirect_to(panel_path(locale: I18n.default_locale))

    get admin_alerts_path
    expect(response).to redirect_to(panel_path(locale: I18n.default_locale))
  end

  it "redirects an unauthenticated user to sign in" do
    get admin_path

    expect(response).to redirect_to(new_session_path(locale: I18n.default_locale))
  end
end
