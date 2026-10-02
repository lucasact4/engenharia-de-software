require "rails_helper"

RSpec.describe "HTML presentation diagrams", type: :feature, js: true do
  def capture(name)
    page.driver.browser.execute_async_script("const done = arguments[arguments.length - 1]; Promise.all([...document.getAnimations()].filter(animation => animation.effect.getComputedTiming().iterations !== Infinity).map(animation => animation.finished.catch(() => {}))).then(done)") if ENV["DIAGRAM_SCREENSHOTS"]
    page.save_screenshot(Rails.root.join("tmp/screenshots/diagrams-#{name}.png")) if ENV["DIAGRAM_SCREENSHOTS"]
  end

  it "highlights related tables and expands an interactive HTML diagram" do
    page.current_window.resize_to(1440, 1000)
    visit "#{presentation_path}#s-modelo-dados"
    diagram = page.find("#s-modelo-dados .apr-data-figure")
    capture("core")
    diagram.find("[data-node='alerts'] .apr-data-node__select").click
    expect(diagram).to have_css("[data-node='alerts'].is-selected")
    expect(diagram).to have_css("[data-node='users'].is-linked")
    expect(diagram).to have_css("[data-relation].is-linked", minimum: 1)

    trigger = diagram.find(".apr-data-zoom")
    trigger.click
    expect(page).to have_css(".apr-lightbox[open] .apr-data-canvas")
    expect(page).to have_no_css(".apr-lightbox[open] svg:not(.apr-icon), .apr-lightbox[open] canvas")
    page.find(".apr-lightbox [data-node='alerts'] .apr-data-node__select").click
    expect(page).to have_css(".apr-lightbox [data-node='alerts'].is-selected")
    expect(page).to have_css(".apr-lightbox .apr-data-selection", text: "alerts.author_id → users · 0..N : 1")
    capture("core-zoom")
    page.find("[data-presentation-target='actualSizeButton']").click
    expect(page).to have_css(".apr-lightbox.is-actual-size")
    page.driver.browser.action.send_keys(:escape).perform
    expect(page).to have_no_css(".apr-lightbox[open]")
    expect(page.evaluate_script("document.activeElement.matches('#s-modelo-dados .apr-data-zoom')")).to be(true)
  end

  it "keeps mobile diagrams readable and scrolls them without changing slides" do
    page.current_window.resize_to(390, 844)
    visit "#{presentation_path}#s-modelo-dados"
    expect(page).to have_css("#s-modelo-dados.is-active")
    viewport = page.find("#s-modelo-dados .apr-data-viewport")
    expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
    expect(page.evaluate_script("parseFloat(getComputedStyle(document.querySelector('#s-modelo-dados .apr-data-canvas')).fontSize)")).to be >= 10
    expect(page.evaluate_script("document.querySelector('#s-modelo-dados .apr-data-viewport').scrollWidth > document.querySelector('#s-modelo-dados .apr-data-viewport').clientWidth")).to be(true)
    page.execute_script("document.querySelector('#s-modelo-dados .apr-data-viewport').scrollLeft = 240")
    capture("mobile")
    expect(viewport).to be_visible
    expect(page).to have_css("#s-modelo-dados.is-active")
  end

  it "renders all diagrams without clipping entity text" do
    page.current_window.resize_to(1440, 1000)
    %w[modelo-conceitual der-operacional der-social der-infraestrutura arquitetura].each do |slide|
      visit "#{presentation_path}#s-#{slide}"
      expect(page).to have_css("#s-#{slide} .apr-data-canvas")
      clipping = page.evaluate_script(<<~JS)
        [...document.querySelectorAll('#s-#{slide} .apr-data-node__select, #s-#{slide} .apr-data-field, #s-#{slide} .apr-data-facts li')]
          .filter(element => element.scrollWidth > element.clientWidth + 1)
          .map(element => element.textContent.trim())
      JS
      expect(clipping).to be_empty, "texto cortado em #{slide}: #{clipping.join(', ')}"
      capture(slide)
    end
  end
end
