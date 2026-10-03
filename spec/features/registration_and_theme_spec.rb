require "rails_helper"

RSpec.describe "Registration and shared themes", type: :feature, js: true do
  around do |example|
    previous = Rails.configuration.x.registration.auto_approve
    Rails.configuration.x.registration.auto_approve = true
    example.run
  ensure
    Rails.configuration.x.registration.auto_approve = previous
  end

  before do
    Role.create!(code: "student", name: "Estudante", active: true)
    visit root_path
    page.execute_script("localStorage.removeItem('sgu.theme')")
    page.driver.browser.navigate.refresh
  end

  it "registers with visible password checks and goes directly to the ordinary portal" do
    visit new_session_path
    click_link "Criar conta"
    expect(page).to have_content("A confirmação de e-mail ainda não foi implementada")
    fill_in "Nome", with: "Estudante Demonstração"
    fill_in "E-mail da UFRPE", with: "estudante.demonstracao@ufrpe.br"
    select "Estudante", from: "Você é um…"
    fill_in "Senha", with: "Senha123!", exact: true
    expect(page).to have_content("Todos os requisitos da senha foram atendidos")
    fill_in "Confirmar senha", with: "Senha123!"
    expect(page).to have_content("As senhas coincidem")
    click_button "Criar minha conta"
    expect(page).to have_current_path(panel_path, ignore_query: true)
    expect(page).to have_content("Conta criada e liberada")
    user = User.find_by!(email_address: "estudante.demonstracao@ufrpe.br")
    expect(user.role?(:student)).to be(true)
    expect(user.admin?).to be(false)
  end

  it "defaults to dark and persists the light preference across login, mural, presentation and reload" do
    expect(page.evaluate_script("document.documentElement.dataset.theme")).to eq("dark")
    find("[data-theme-toggle]").click
    expect(page.evaluate_script("document.documentElement.dataset.theme")).to eq("light")
    [ new_session_path, new_registration_path, publications_path, presentation_path ].each do |path|
      visit path
      expect(page.evaluate_script("document.documentElement.dataset.theme")).to eq("light")
      expect(page).to have_button("Ativar modo escuro")
      expect(page.evaluate_script("getComputedStyle(document.querySelector('[data-theme-toggle]')).color")).to eq("rgb(21, 40, 35)")
    end
    page.driver.browser.navigate.refresh
    expect(page.evaluate_script("document.documentElement.dataset.theme")).to eq("light")
    find("[data-theme-toggle]").click
    expect(page.evaluate_script("localStorage.getItem('sgu.theme')")).to eq("dark")
  end

  it "hides inactive presentation slides on mobile without overlapping content" do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit presentation_path
    expect(page).to have_css(".apr--presenting .apr-slide.is-active", count: 1)
    visible = page.evaluate_script("Array.from(document.querySelectorAll('.apr-slide')).filter(slide => getComputedStyle(slide).visibility === 'visible' && getComputedStyle(slide).display !== 'none').length")
    expect(visible).to eq(1)
  ensure
    page.driver.browser.manage.window.resize_to(1280, 900)
  end

  it "keeps the dark theme and essential actions usable on mobile" do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit new_registration_path
    expect(page).to have_button("Criar minha conta")
    expect(page).to have_button("Ativar modo claro")
    overflow = page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
    expect(overflow).to be(false)
    visit publications_path
    find("summary[aria-label='Abrir menu']").click
    expect(page).to have_link("Criar conta", visible: true)
  ensure
    page.driver.browser.manage.window.resize_to(1280, 900)
  end
end
