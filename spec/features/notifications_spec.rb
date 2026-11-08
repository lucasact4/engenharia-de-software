require "rails_helper"

RSpec.describe "Notification delivery", type: :feature, js: true do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  it "lets a person opt into email and select a reference location" do
    location = create(:location, name: "Biblioteca", reference_latitude: -8.01, reference_longitude: -34.95)
    sign_in_via_ui(user)
    visit notifications_path
    find("summary", text: "Preferências de entrega").click
    check "Receber atualizações e alertas próximos por e-mail"
    select location.name, from: "Local de referência para alertas próximos"
    click_button "Salvar preferências"
    expect(page).to have_content("Preferências de notificações salvas.")
    expect(NotificationPreference.find_by!(user: user)).to have_attributes(email_enabled: true, location: location)
  end

  def new_comment
    publication = create(:publication, :published, author: user)
    create(:comment, publication: publication)
  end

  it "opens the mini window on hover and keeps unread status until explicitly read" do
    new_comment
    sign_in_via_ui(user)
    find('summary[aria-label="Notificações"]').hover
    within("#notification-preview") do
      expect(page).to have_content("Um novo comentário")
      expect(page).to have_content("Não lida")
      click_button "Marcar como lida"
      expect(page).to have_content("Lida")
    end
    expect(user.notifications.sole.read_at).to be_present
  end

  it "supports click, keyboard activation and Escape on a narrow screen" do
    new_comment
    sign_in_via_ui(user)
    page.current_window.resize_to(390, 844)
    find('summary[aria-label="Notificações"]').click
    expect(page).to have_css("#notification-preview", visible: true)
    expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
    page.save_screenshot("/results/notificacoes-mobile.png") if ENV["NOTIFICATION_SCREENSHOTS"]
    find('summary[aria-label="Notificações"]').send_keys(:escape)
    expect(page).not_to have_css("#notification-preview", visible: true)
    find('summary[aria-label="Notificações"]').send_keys(:enter)
    expect(page).to have_css("#notification-preview", visible: true)
    within("#notification-preview") { click_button "Fechar" }
    expect(page).to have_css('summary[aria-label="Notificações"]:focus')
    expect(user.notifications.sole.read_at).to be_nil
  ensure
    page.current_window.resize_to(1024, 786)
  end

  it "delivers new panic events while security keeps working, then drains the queue" do
    grant_role(user, :security)
    sign_in_via_ui(user)
    expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
    first = create(:alert, :panic)
    second = create(:alert, :panic)
    within(".notification-urgent", wait: 10) do
      expect(page).to have_content(first.protocol, wait: 10)
      expect(page).to have_css('[role="alertdialog"]')
      page.save_screenshot("/results/notificacoes-panico.png") if ENV["NOTIFICATION_SCREENSHOTS"]
      click_button "Reconhecer alerta"
      expect(page).to have_content(second.protocol, wait: 10)
      click_button "Reconhecer alerta"
    end
    expect(page).not_to have_css(".notification-urgent", visible: true)
    expect(user.notifications.unread).to be_empty
  end

  it "shows panic popups in the admin layout and keeps unacknowledged alerts after reload" do
    admin
    panic = create(:alert, :panic)
    sign_in_via_ui(admin)
    expect(page).to have_css(".notification-urgent", text: panic.protocol)
    page.refresh
    expect(page).to have_css(".notification-urgent", text: panic.protocol)
    within(".notification-urgent") { click_button "Reconhecer alerta" }
    expect(page).not_to have_css(".notification-urgent", visible: true)
    page.refresh
    expect(page).not_to have_css(".notification-urgent", visible: true)
  end

  it "recovers pending notifications after a network outage" do
    sign_in_via_ui(user)
    page.execute_script("window.originalFetch = window.fetch; window.fetch = () => Promise.reject(new TypeError('offline'))")
    new_comment
    find('summary[aria-label="Notificações"]').click
    expect(page).to have_content("Sem conexão", wait: 10)
    page.execute_script("window.fetch = window.originalFetch")
    within("#notification-preview") { expect(page).to have_content("Um novo comentário", wait: 10) }
  end

  it "keeps preview forms working when JavaScript is unavailable" do
    new_comment
    sign_in_via_ui(user)
    visit notifications_path
    page.execute_script("document.querySelector('body').removeAttribute('data-controller')")
    within("main") { click_button "Marcar como lida" }
    expect(page).to have_content("Lida")
    expect(user.notifications.sole.read_at).to be_present
  end

  it "submits reading with actual CSRF protection enabled" do
    new_comment
    sign_in_via_ui(user)
    ActionController::Base.allow_forgery_protection = true
    visit panel_path
    find('summary[aria-label="Notificações"]').click
    within("#notification-preview") do
      click_button "Marcar como lida"
      expect(page).to have_content("Lida")
    end
    expect(user.notifications.sole.read_at).to be_present
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  it "restores polling and preview contents after Turbo back navigation" do
    new_comment
    sign_in_via_ui(user)
    find('summary[aria-label="Notificações"]').click
    within("#notification-preview") { click_link "Ver todas as notificações" }
    expect(page).to have_content("Suas notificações")
    page.go_back
    find('summary[aria-label="Notificações"]').click
    within("#notification-preview") { expect(page).to have_content("Um novo comentário", wait: 10) }
  end

  it "retries when a request hangs instead of blocking delivery forever" do
    sign_in_via_ui(user)
    page.execute_script(<<~JS)
      window.originalFetch = window.fetch
      window.fetch = (_url, options) => new Promise((_ok, reject) => {
        options.signal.addEventListener("abort", () => reject(new DOMException("timeout", "AbortError")))
      })
    JS
    new_comment
    find('summary[aria-label="Notificações"]').click
    expect(page).to have_content("Sem conexão", wait: 15)
    page.execute_script("window.fetch = window.originalFetch")
    within("#notification-preview") { expect(page).to have_content("Um novo comentário", wait: 15) }
  end
end
