require "rails_helper"

RSpec.describe SessionsController, type: :routing do
  it "routes the friendly sign-in URL" do
    expect(get: "/entrar").to route_to("sessions#new")
  end

  it "uses the same friendly URL to create a session" do
    expect(post: "/entrar").to route_to("sessions#create")
  end
end
