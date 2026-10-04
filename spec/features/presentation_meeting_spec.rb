require "rails_helper"
require "base64"

RSpec.describe "Presentation meeting evidence", type: :feature, js: true do
  before { @original_size = page.driver.browser.manage.window.size }
  after { page.driver.browser.manage.window.resize_to(@original_size.width, @original_size.height) }

  def capture(name, width: 1440, height: 1100)
    page.driver.browser.manage.window.resize_to(width, height)
    expect(page).to have_css("body") { page.evaluate_script("document.documentElement.scrollWidth <= innerWidth") }
    expect(page).to have_css("body") { page.evaluate_script("document.fonts.status === 'loaded' && [...document.images].filter(image => image.getClientRects().length > 0).every(image => image.complete && image.naturalWidth > 0)") }
    directory = Rails.root.join("tmp/qa_presentation")
    FileUtils.mkdir_p(directory)
    page.save_screenshot(directory.join("#{name}.png"))
  end

  it "opens each original, restores focus and prints one page per selected slide" do
    presentation = Presentation.load
    choices = presentation.slides.reject(&:required).to_h { |slide| [ slide.id, slide.id == "reunioes" ] }
    create(:presentation_profile, :active, selections: choices)
    visit "#{presentation_path}#s-reunioes"
    expect(page).to have_css("#s-reunioes.is-active")
    expect(page).to have_css(".apr-figure--meeting img", count: 4)
    expect(page).to have_content("18h20 (aproximadamente)")
    capture("meeting-desktop")
    page.all("#s-reunioes .apr-figure__zoom").each do |trigger|
      trigger.click
      expect(page).to have_css(".apr-lightbox[open] img") { |image| image["src"].end_with?(trigger["data-zoom-src"]) }
      page.driver.browser.action.send_keys(:escape).perform
      expect(page).to have_no_css(".apr-lightbox[open]")
      expect(page.evaluate_script("document.activeElement === arguments[0]", trigger.native)).to be(true)
    end
    capture("meeting-mobile", width: 390, height: 844)
    page.execute_script("document.querySelector('.apr-meeting__gallery').scrollIntoView({ block: 'start' })")
    capture("meeting-mobile-gallery", width: 390, height: 844)
    pdf = page.driver.browser.send(:bridge).send(:execute, :print_page, {}, {
      orientation: "landscape", page: { width: 21.0, height: 29.7 }, background: true, shrinkToFit: false
    })
    content = Base64.strict_decode64(pdf)
    expect(content.scan(%r{/Type\s*/Page\b(?!s)}).size).to eq(3)
    File.binwrite(Rails.root.join("tmp/qa_presentation/meeting.pdf"), content)

    visit root_path
    page.execute_script("localStorage.removeItem('sgu.theme'); document.documentElement.dataset.theme = 'dark'")
    capture("landing-desktop", width: 1440, height: 1000)
    total_height = page.evaluate_script("document.documentElement.scrollHeight")
    capture("landing-completa", width: 1440, height: total_height)
    capture("landing-mobile", width: 390, height: 844)
    visit new_session_path
    capture("entrar-desktop", width: 1440, height: 1000)
  end
end
