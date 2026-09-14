require "rails_helper"

RSpec.describe "Public home", type: :request do
  it "renders the landing page without authentication" do
    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Uma UFRPE mais segura")
    expect(response.body).to include("href=\"/entrar\"")
  end
end
