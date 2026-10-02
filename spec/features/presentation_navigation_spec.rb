require "rails_helper"
require "base64"

RSpec.describe "Presentation navigation", type: :feature, js: true do
  let(:presentation) { Presentation.load }
  let(:main_count) { presentation.default_selection.visible_main_slides.size }

  def slide_counter
    page.find("[data-presentation-target='counter']")
  end

  def press(key)
    page.driver.browser.action.send_keys(key).perform
  end

  def open_customize
    click_button "Personalizar apresentação"
    expect(page).to have_css(".apr-custom[open]")
  end

  def toggle(key)
    page.find(".apr-custom input[data-apr-toggle='#{key}']").click
  end

  # Gera o PDF pelo mesmo comando usado em script/exportar_apresentacao_pdf.rb e conta as páginas.
  def printed_pages
    pdf = page.driver.browser.send(:bridge).send(:execute, :print_page, {}, {
      orientation: "landscape", page: { width: 21.0, height: 29.7 }, background: true, shrinkToFit: false
    })
    Base64.strict_decode64(pdf).scan(%r{/Type\s*/Page\b(?!s)}).size
  end

  it "navigates with the keyboard without entering the appendices" do
    visit presentation_path
    expect(slide_counter).to have_text("1 / #{main_count}")
    press(:arrow_right)
    expect(slide_counter).to have_text("2 / #{main_count}")
    press(:end)
    expect(slide_counter).to have_text("#{main_count} / #{main_count}")
    expect(page).to have_css("#s-encerramento.is-active")
    press(:arrow_right)
    expect(slide_counter).to have_text("#{main_count} / #{main_count}")
  end

  it "ignores a malformed fragment instead of breaking initialization" do
    visit "#{presentation_path}#s-%ZZ"
    expect(slide_counter).to have_text("1 / #{main_count}")
    page.find("[data-presentation-target='nextButton']").click
    expect(slide_counter).to have_text("2 / #{main_count}")
  end

  it "restores focus to the image trigger after closing the lightbox" do
    visit "#{presentation_path}#s-conceito-visual"
    trigger = page.find("#s-conceito-visual .apr-figure--hero .apr-figure__zoom")
    trigger.click
    expect(page).to have_css(".apr-lightbox[open]")
    press(:escape)
    expect(page).to have_no_css(".apr-lightbox[open]")
    expect(page.evaluate_script("document.activeElement === document.querySelector('#s-conceito-visual .apr-figure--hero .apr-figure__zoom')")).to be(true)
  end

  it "keeps all slides interactive in reading mode" do
    visit "#{presentation_path}?modo=leitura"
    expect(page).to have_css(".apr-toc", visible: true)
    expect(page).to have_no_css(".apr--presenting")
    expect(page.evaluate_script("[...document.querySelectorAll('.apr-slide')].every(slide => !slide.inert)")).to be(true)
  end

  describe "with a saved profile" do
    let!(:profile) do
      create(:presentation_profile, :active, selections: { "escopo" => false, "gestao.reunioes" => false, "conflitos" => false })
    end

    it "skips slides hidden by the profile and falls back from a hidden fragment" do
      visit "#{presentation_path}#s-escopo"

      expect(page).to have_css("#s-evolucao.is-active")
      expect(page.evaluate_script("location.hash")).to eq("#s-evolucao")
      expect(page).to have_no_css("#s-escopo", visible: true)
      expect(page).to have_no_css("[data-apr-item='gestao.reunioes']", visible: true)
    end

    it "lists only the selected slides in the index, with recalculated labels" do
      visit presentation_path
      click_button "Índice"

      within(".apr-index") do
        expect(page).to have_no_link("Escopo do MVP e regras")
        expect(page).to have_no_link("Requisitos em conflito")
        expect(page.find("a[href='#s-evolucao'] .apr-slide-list__label")).to have_text("03")
        expect(page.find("a[href='#s-modelo-dados'] .apr-slide-list__label")).to have_text("B")
      end
    end
  end

  describe "temporary adjustments" do
    let!(:profile) { create(:presentation_profile, :active, selections: { "gestao.reunioes" => true }) }

    it "hides the current slide only in the browser and moves to the next visible slide" do
      visit "#{presentation_path}#s-gestao"
      expect(page).to have_css("#s-gestao.is-active")
      updated_at = profile.reload.updated_at

      open_customize
      expect(page.evaluate_script("document.activeElement.id")).to eq("apr-custom-titulo")
      expect(page).to have_text("Ajustes temporários")
      toggle("gestao")

      expect(page).to have_css("#s-retrospectiva.is-active", visible: :all)
      expect(page.find(".apr-custom__status")).to have_text("Ajustes temporários ativos")

      press(:escape)
      expect(page).to have_no_css(".apr-custom[open]")
      expect(page.evaluate_script("document.activeElement.id")).to eq("s-retrospectiva")
      expect(page.evaluate_script("location.hash")).to eq("#s-retrospectiva")
      expect(slide_counter).to have_text("/ #{main_count - 1}")

      expect(profile.reload.updated_at).to eq(updated_at)
      expect(profile.selections).to eq("gestao.reunioes" => true)

      visit presentation_path
      expect(slide_counter).to have_text("1 / #{main_count}")
      expect(page).to have_css("#s-gestao", visible: :all)
      expect(page.evaluate_script("document.querySelector('#s-gestao').hidden")).to be(false)
    end

    it "hides contents without leaving empty columns and restores the profile" do
      visit "#{presentation_path}#s-gestao"
      open_customize
      %w[gestao.trello gestao.cards gestao.ambientes].each { |key| toggle(key) }
      press(:escape)

      expect(page).to have_no_css("#s-gestao [aria-labelledby='s-gestao-trello']", visible: true)
      columns = page.evaluate_script("getComputedStyle(document.querySelector('#s-gestao .apr-mgmt')).gridTemplateColumns.split(' ').length")
      expect(columns).to eq(2)

      open_customize
      click_button "Restaurar padrão do perfil"
      expect(page.find(".apr-custom__status")).to have_text("Padrão do perfil restaurado")
      click_button "Concluir"
      expect(page).to have_css("#s-gestao [aria-labelledby='s-gestao-trello']", visible: true)
    end

    it "keeps the cover and the closing slide when every optional slide is hidden" do
      visit presentation_path
      open_customize
      expect(page.find(".apr-custom input[data-apr-toggle='capa']")).to be_disabled
      expect(page.find(".apr-custom input[data-apr-toggle='encerramento']")).to be_disabled

      presentation.slides.reject(&:required).each { |slide| toggle(slide.id) if page.find(".apr-custom input[data-apr-toggle='#{slide.id}']").checked? }
      press(:escape)

      expect(slide_counter).to have_text("1 / 2")
      press(:arrow_right)
      expect(page).to have_css("#s-encerramento.is-active")
      expect(page).to have_text("Obrigado!")
      expect(printed_pages).to eq(2)
    end

    it "updates the estimate, the appendix labels and the printout" do
      visit presentation_path
      expect(printed_pages).to eq(presentation.default_selection.visible_slides.size)

      open_customize
      toggle("checklist")
      toggle("funcionalidades")
      expect(page.find(".apr-custom__estimate")).to have_text("em #{main_count - 1} slides principais")
      press(:escape)

      click_button "Índice"
      expect(page.find(".apr-index a[href='#s-conflitos'] .apr-slide-list__label")).to have_text("A")
      press(:escape)

      expect(printed_pages).to eq(presentation.default_selection.visible_slides.size - 2)
    end
  end
end
