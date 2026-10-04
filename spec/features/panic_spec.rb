require "rails_helper"

RSpec.describe "Panic button", type: :feature, js: true do
  let(:user) { create(:user) }

  before { sign_in_via_ui user }

  it "asks for a short confirmation, sends without waiting for GPS forever and shows an honest receipt" do
    visit new_panic_path
    page.execute_script("navigator.geolocation.getCurrentPosition = () => {}") # permissão nunca respondida

    click_button "Pedir ajuda"
    click_button "Confirmar pedido de ajuda"

    expect(page).to have_content("O sistema recebeu este pedido de ajuda", wait: 15)
    expect(page).to have_content("não significa que uma pessoa já viu o pedido")
    expect(Alert.panic.last).to have_attributes(location_source: "unavailable", location_unavailable_reason: "timeout")
  end

  it "resends the same frozen request after a network failure without duplicating" do
    visit new_panic_path
    page.execute_script(<<~JS)
      navigator.geolocation.getCurrentPosition = (_ok, fail) => fail({ code: 1 })
      window.__realFetch = window.fetch
      window.fetch = () => Promise.reject(new TypeError("offline"))
    JS

    click_button "Pedir ajuda"
    click_button "Confirmar pedido de ajuda"
    expect(page).to have_content("Sem conexão: não foi possível confirmar se o pedido chegou")
    expect(Alert.panic.count).to eq(0)

    page.execute_script("window.fetch = window.__realFetch")
    click_button "Reenviar o mesmo pedido"
    expect(page).to have_content("O sistema recebeu este pedido de ajuda", wait: 10)
    expect(Alert.panic.count).to eq(1)
    expect(Alert.panic.last.location_unavailable_reason).to eq("permission_denied")
  end
end
