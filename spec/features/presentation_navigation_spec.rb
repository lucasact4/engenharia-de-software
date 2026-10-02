require "rails_helper"
require "base64"
require "open3"
require "tmpdir"

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
      create(:presentation_profile, :active, selections: { "escopo" => false, "reunioes.registros" => false, "conflitos" => false, "checklist" => true, "modelo-dados" => true })
    end

    it "skips slides hidden by the profile and falls back from a hidden fragment" do
      visit "#{presentation_path}#s-escopo"

      expect(page).to have_css("#s-encerramento.is-active")
      expect(page.evaluate_script("location.hash")).to eq("#s-encerramento")
      expect(page).to have_no_css("#s-escopo", visible: true)
      expect(page).to have_no_css("[data-apr-item='reunioes.registros']", visible: true)
    end

    it "lists only the selected slides in the index, with recalculated labels" do
      visit presentation_path
      click_button "Índice"

      within(".apr-index") do
        expect(page).to have_no_link("Escopo do MVP e regras")
        expect(page).to have_no_link("Requisitos em conflito")
        expect(page.find("a[href='#s-evolucao'] .apr-slide-list__label")).to have_text("06")
        expect(page.find("a[href='#s-modelo-dados'] .apr-slide-list__label")).to have_text("B")
      end
    end
  end

  describe "temporary adjustments" do
    let!(:profile) { create(:presentation_profile, :active, selections: { "reunioes.registros" => true }) }

    it "hides the current slide only in the browser and moves to the next visible slide" do
      visit "#{presentation_path}#s-reunioes"
      expect(page).to have_css("#s-reunioes.is-active")
      updated_at = profile.reload.updated_at

      open_customize
      expect(page.evaluate_script("document.activeElement.id")).to eq("apr-custom-titulo")
      expect(page).to have_text("Ajustes temporários")
      toggle("reunioes")

      expect(page).to have_css("#s-evolucao.is-active", visible: :all)
      expect(page.find(".apr-custom__status")).to have_text("Ajustes temporários ativos")

      press(:escape)
      expect(page).to have_no_css(".apr-custom[open]")
      expect(page.evaluate_script("document.activeElement.id")).to eq("s-evolucao")
      expect(page.evaluate_script("location.hash")).to eq("#s-evolucao")
      expect(slide_counter).to have_text("/ #{main_count - 1}")

      expect(profile.reload.updated_at).to eq(updated_at)
      expect(profile.selections).to eq("reunioes.registros" => true)

      visit presentation_path
      expect(slide_counter).to have_text("1 / #{main_count}")
      expect(page).to have_css("#s-reunioes", visible: :all)
      expect(page.evaluate_script("document.querySelector('#s-reunioes').hidden")).to be(false)
    end

    it "hides contents without leaving empty columns and restores the profile" do
      profile.update!(selections: profile.selections.merge("repositorio" => true))
      visit "#{presentation_path}#s-repositorio"
      open_customize
      toggle("repositorio.praticas")
      press(:escape)

      expect(page).to have_no_css("#s-repositorio [aria-labelledby='s-repositorio-praticas']", visible: true)
      columns = page.evaluate_script("getComputedStyle(document.querySelector('#s-repositorio .apr-mgmt')).gridTemplateColumns.split(' ').length")
      expect(columns).to eq(1)

      open_customize
      click_button "Restaurar padrão do perfil"
      expect(page.find(".apr-custom__status")).to have_text("Padrão do perfil restaurado")
      click_button "Concluir"
      expect(page).to have_css("#s-repositorio [aria-labelledby='s-repositorio-praticas']", visible: true)
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
      profile.update!(selections: profile.selections.merge("checklist" => true, "conflitos" => true))
      visit presentation_path
      expect(printed_pages).to eq(profile.selection(presentation).visible_slides.size)

      open_customize
      toggle("checklist")
      toggle("funcionalidades")
      expect(page.find(".apr-custom__estimate")).to have_text("em #{main_count - 1} slides principais")
      press(:escape)

      click_button "Índice"
      expect(page.find(".apr-index a[href='#s-conflitos'] .apr-slide-list__label")).to have_text("A")
      press(:escape)

      expect(printed_pages).to eq(profile.selection(presentation).visible_slides.size - 2)
    end
  end


  it "exports the reading deck with logos outside the viewport loaded" do
    visit "#{presentation_path}?modo=leitura"
    uri = URI(page.current_url)
    uri.host = "rails-app"
    # O serviço Selenium admite uma sessão: libera a do Capybara antes de abrir o exportador.
    page.driver.quit

    Dir.mktmpdir("presentation-export") do |directory|
      output = File.join(directory, "presentation.pdf")
      stdout, stderr, status = Open3.capture3(
        { "APRESENTACAO_URL" => uri.to_s }, RbConfig.ruby,
        Rails.root.join("script/exportar_apresentacao_pdf.rb").to_s, output
      )
      expect(status.success?).to be(true), "Falha na exportação: #{stdout}\n#{stderr}"
      pdf = File.binread(output)
      expect(pdf).to start_with("%PDF-")
      expect(pdf.scan(%r{/Type\s*/Page\b(?!s)}).size).to eq(presentation.default_selection.visible_slides.size)
    end
  end

  describe "technology versions" do
    before { create(:presentation_profile, :active, selections: { "arquitetura" => true }) }
    it "shows a version on keyboard focus, expands and collapses all of them, and keeps the profile untouched" do
      profile = PresentationProfile.find_by!(active: true)
      visit "#{presentation_path}#s-arquitetura"
      versions = "#s-arquitetura .apr-tech__card:first-of-type .apr-tech__versions"

      expect(page.evaluate_script("getComputedStyle(document.querySelector('#{versions}')).visibility")).to eq("hidden")
      page.execute_script("document.querySelector('#s-arquitetura .apr-tech__item').focus()")
      expect(page.evaluate_script("getComputedStyle(document.querySelector('#{versions}')).visibility")).to eq("visible")
      press(:escape)
      expect(page.evaluate_script("getComputedStyle(document.querySelector('#{versions}')).visibility")).to eq("hidden")

      click_button "Mostrar versões"
      expect(page).to have_button("Ocultar versões")
      expect(page.find("#s-arquitetura .apr-tech__toggle")["aria-expanded"]).to eq("true")
      expect(page).to have_css("#s-arquitetura .apr-tech.is-expanded .apr-tech__versions", text: Rails.version)
      click_button "Ocultar versões"
      expect(page).to have_button("Mostrar versões")
      expect(profile.reload.selections).to eq("arquitetura" => true)
    end

    it "keeps the tooltip open while the pointer moves over its text" do
      visit "#{presentation_path}#s-arquitetura"
      card = page.find("#s-arquitetura .apr-tech__card", text: "Ruby", match: :first)
      card.find(".apr-tech__item").hover
      tooltip = card.find("[role=tooltip]", visible: true)
      tooltip.hover
      expect(tooltip).to be_visible
      expect(page.evaluate_script("getComputedStyle(document.querySelector('#s-arquitetura .apr-tech__versions')).pointerEvents")).to eq("auto")
    end

    it "fits the expanded cards on a phone without horizontal page overflow" do
      page.current_window.resize_to(390, 844)
      visit "#{presentation_path}#s-arquitetura"
      click_button "Mostrar versões"
      expect(page).to have_button("Ocultar versões")
      expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
      expect(page.evaluate_script(<<~JS)).to be_empty
        [...document.querySelectorAll('#s-arquitetura .apr-tech__version')]
          .filter(element => element.scrollWidth > element.clientWidth + 1)
          .map(element => element.textContent.trim())
      JS
    ensure
      page.current_window.resize_to(1024, 786)
    end

    it "removes the version controls when Versões is unchecked in the panel" do
      visit "#{presentation_path}#s-arquitetura"
      expect(page).to have_button("Mostrar versões")

      open_customize
      toggle("arquitetura.versoes")
      press(:escape)

      expect(page).to have_no_button("Mostrar versões")
      expect(page).to have_no_css("#s-arquitetura .apr-tech__versions", visible: :visible)
    end
  end

  it "uses the requirement titles of the profile delivery in the counter and index" do
    create(:presentation_profile, :active, delivery: "primeira", selections: { "gestao" => true })
    visit "#{presentation_path}#s-gestao"

    expect(page.find("[data-presentation-target='currentTitle']", visible: :all).text(:all)).to eq("Ferramenta de monitoramento dos projetos ativa com os requisitos e links para ambientes — Trello")
    expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
    click_button "Índice"
    expect(page).to have_css(".apr-index .apr-slide-list__req", text: "1ª entrega · Item 4")
  end
end
