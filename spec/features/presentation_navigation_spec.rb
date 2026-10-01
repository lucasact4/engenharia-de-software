require "rails_helper"

RSpec.describe "Presentation navigation", type: :feature, js: true do
  def slide_counter
    page.find("[data-presentation-target='counter']")
  end

  it "navigates with the keyboard without entering the appendices" do
    visit presentation_path
    expect(slide_counter).to have_text("1 / 11")
    page.driver.browser.action.send_keys(:arrow_right).perform
    expect(slide_counter).to have_text("2 / 11")
    page.driver.browser.action.send_keys(:end).perform
    expect(slide_counter).to have_text("11 / 11")
    page.driver.browser.action.send_keys(:arrow_right).perform
    expect(slide_counter).to have_text("11 / 11")
  end

  it "ignores a malformed fragment instead of breaking initialization" do
    visit "#{presentation_path}#s-%ZZ"
    expect(slide_counter).to have_text("1 / 11")
    page.find("[data-presentation-target='nextButton']").click
    expect(slide_counter).to have_text("2 / 11")
  end

  it "restores focus to the image trigger after closing the lightbox" do
    visit "#{presentation_path}#s-conceito-visual"
    trigger = page.find("#s-conceito-visual .apr-figure--hero .apr-figure__zoom")
    trigger.click
    expect(page).to have_css(".apr-lightbox[open]")
    page.driver.browser.action.send_keys(:escape).perform
    expect(page).to have_no_css(".apr-lightbox[open]")
    expect(page.evaluate_script("document.activeElement === document.querySelector('#s-conceito-visual .apr-figure--hero .apr-figure__zoom')")).to be(true)
  end

  it "keeps all slides interactive in reading mode" do
    visit "#{presentation_path}?modo=leitura"
    expect(page).to have_css(".apr-toc", visible: true)
    expect(page).to have_no_css(".apr--presenting")
    expect(page.evaluate_script("[...document.querySelectorAll('.apr-slide')].every(slide => !slide.inert)")).to be(true)
  end
end
