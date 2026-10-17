require "rails_helper"
require "base64"

# Viewport 1920×1080 (equivale à tela cheia em um monitor Full HD), modo apresentação e
# perfil padrão da 2ª entrega (sem perfil salvo: escolhas "padrao" do roteiro.yml).
RSpec.describe "Presentation revision", type: :feature, js: true do
  let(:presentation) { Presentation.load }
  let(:main_slides) { presentation.default_selection.visible_main_slides }

  before { @original_size = page.driver.browser.manage.window.size }
  after { page.driver.browser.manage.window.resize_to(@original_size.width, @original_size.height) }

  def viewport(width, height)
    window = page.driver.browser.manage.window
    window.resize_to(width, height)
    inner_width, inner_height = page.evaluate_script("[innerWidth, innerHeight]")
    window.resize_to(width + (width - inner_width), height + (height - inner_height))
    expect(page.evaluate_script("[innerWidth, innerHeight]")).to eq([ width, height ])
  end

  def press(*keys)
    page.driver.browser.action.send_keys(*keys).perform
  end

  # Espera fontes, imagens do slide e animações de entrada antes de medir.
  def settle(slide_id)
    expect(page).to have_css("##{slide_id}.is-active")
    expect(page).to have_css("body") do
      page.evaluate_script(<<~JS)
        document.fonts.status === "loaded" &&
          [...document.querySelectorAll("##{slide_id} img")].filter(image => image.getClientRects().length > 0)
            .every(image => image.complete && image.naturalWidth > 0)
      JS
    end
    page.driver.browser.execute_async_script(<<~JS)
      const done = arguments[arguments.length - 1];
      Promise.all(document.getAnimations().map(animation => animation.finished.catch(() => {}))).then(done);
    JS
  end

  def overflow(slide_id)
    page.evaluate_script(<<~JS)
      (() => {
        const slide = document.getElementById("#{slide_id}");
        const box = slide.getBoundingClientRect();
        // Diagramas rolam por dentro; janelas, informações e detalhes fechados não ocupam espaço.
        const outside = [...slide.querySelectorAll("*")].filter(element => {
          if (element.closest("dialog, [popover], .apr-data-canvas, details:not([open]) > :not(summary)")) return false;
          const rect = element.getBoundingClientRect();
          return rect.width > 0 && rect.height > 0 &&
            (rect.right > box.right + 1 || rect.left < box.left - 1 || rect.bottom > box.bottom + 1);
        }).map(element => element.className || element.tagName);
        return { vertical: slide.scrollHeight - slide.clientHeight, horizontal: slide.scrollWidth - slide.clientWidth, outside };
      })()
    JS
  end

  it "fits every main slide of the second delivery at 1920×1080 without scrolling" do
    viewport(1920, 1080)
    visit presentation_path
    expect(main_slides.map(&:id)).to eq(%w[capa conceito-visual funcionalidades retrospectiva modelo-conceitual reunioes evolucao proximos-passos status-report encerramento])

    directory = Rails.root.join("tmp/qa_refinement")
    FileUtils.mkdir_p(directory)
    %w[dark light].each do |theme|
      page.execute_script("document.documentElement.dataset.theme = arguments[0]", theme)
      main_slides.each do |slide|
        page.execute_script("location.hash = arguments[0]", slide.dom_id)
        settle(slide.dom_id)
        result = overflow(slide.dom_id)
        expect(result).to eq("vertical" => 0, "horizontal" => 0, "outside" => []), "#{theme}/#{slide.id}: #{result.inspect}"
        page.save_screenshot(directory.join("#{slide.id}-#{theme}.png"))
      end
    end
  end

  it "keeps all slides and navigation within phone, tablet and laptop widths" do
    visit presentation_path
    [ [ 320, 568 ], [ 390, 844 ], [ 768, 1024 ], [ 1366, 768 ] ].each do |width, height|
      viewport(width, height)
      %w[dark light].each do |theme|
        page.execute_script("document.documentElement.dataset.theme = arguments[0]", theme)
        main_slides.each do |slide|
          page.execute_script("location.hash = arguments[0]", slide.dom_id)
          settle(slide.dom_id)
          expect(overflow(slide.dom_id)["horizontal"]).to eq(0), "#{width}/#{theme}/#{slide.id}"
          expect(page.evaluate_script("document.documentElement.scrollWidth <= innerWidth")).to be(true)
        end
      end
      expect(page.evaluate_script("[...document.querySelectorAll('.apr-nav button, .apr-timer__display')].filter(node => node.getClientRects().length > 0).every(node => {const r = node.getBoundingClientRect(); return r.left >= 0 && r.right <= innerWidth && r.bottom <= innerHeight})")).to be(true)
    end
  end

  it "starts paused, keeps elapsed time across tab changes, pauses, resets and edits the timer" do
    visit presentation_path
    expect(page).to have_css(".apr-timer__display", text: "07:00")
    advance = ->(seconds) { page.execute_script("const timer = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector('.apr-timer'), 'presentation-timer'); if (timer.running) timer.deadline -= arguments[0] * 1000; document.dispatchEvent(new Event('visibilitychange'))", seconds) }
    find("button[aria-label='Iniciar contador']").click
    advance.call(10)
    expect(page).to have_css(".apr-timer__display", text: "06:50")
    find("button[aria-label='Pausar contador']").click
    advance.call(20)
    expect(page).to have_css(".apr-timer__display", text: "06:50")
    find("button[aria-label='Iniciar contador']").click
    advance.call(15)
    expect(page).to have_css(".apr-timer__display", text: "06:35")
    find("button[aria-label='Resetar contador']").click
    expect(page).to have_css("button[aria-label='Iniciar contador']")
    expect(page).to have_css(".apr-timer__display", text: "07:00")
    find("button[aria-label='Modificar tempo']").click
    expect(page).to have_css(".apr-timer__editor[open]")
    fill_in "Minutos", with: "0"
    click_button "Aplicar tempo"
    expect(page).to have_css(".apr-timer__editor[open]")
    fill_in "Minutos", with: "1"
    click_button "Aplicar tempo"
    expect(page).to have_no_css(".apr-timer__editor[open]")
    expect(page).to have_css(".apr-timer__display", text: "01:00")
    find("button[aria-label='Iniciar contador']").click
    advance.call(60)
    expect(page).to have_css(".apr-timer.is-finished .apr-timer__display", text: "00:00")
    expect(page).to have_css("button[aria-label='Iniciar contador']")
    expect(page).to have_css("#s-capa.is-active")
  end

  it "enlarges the QR from the cover and compact navigation while keeping its public link" do
    viewport(390, 844)
    visit presentation_path
    trigger = find("#s-capa .apr-access__code")
    trigger.click
    expect(page).to have_css(".apr-lightbox[open] img[src*='apresentacao-qr']")
    press(:escape)
    expect(page.evaluate_script("document.activeElement === arguments[0]", trigger.native)).to be(true)
    find(".apr-share-button").click
    expect(page).to have_css(".apr-lightbox[open] img[src*='apresentacao-qr']")
    press(:escape)
    expect(find("#s-capa .apr-access a")["href"]).to eq("https://eduardo-hulkier-zayne.ngrok-free.dev/apresentacao#s-capa")
  end

  it "shows an index without per-slide duration and readable timer contrast in the light theme" do
    viewport(1920, 1080)
    visit presentation_path
    page.execute_script("document.documentElement.dataset.theme = 'light'")
    click_button "Índice"
    expect(page).to have_css(".apr-index[open]")
    expect(page).to have_no_css(".apr-index .apr-slide-list__time", visible: :all)
    page.save_screenshot(Rails.root.join("tmp/qa_refinement/index-light.png"))
    press(:escape)
    expect(page.evaluate_script("getComputedStyle(document.querySelector('.apr-timer__display')).color")).to eq("rgb(237, 245, 243)")
  end

  it "switches the visual concept captures and their enlargement with the system theme" do
    viewport(1920, 1080)
    visit "#{presentation_path}#s-conceito-visual"
    page.execute_script("localStorage.removeItem('sgu.theme')")
    visit "#{presentation_path}#s-conceito-visual"
    settle("s-conceito-visual")

    visible = lambda do |selector|
      page.evaluate_script("[...document.querySelectorAll(#{selector.to_json})].filter(image => getComputedStyle(image).display !== 'none').map(image => image.getAttribute('src').split('/').pop())")
    end
    expect(visible.call("#s-conceito-visual .apr-figure--hero img")).to contain_exactly(match(/\Alanding-desktop-\h+\.png\z/))

    find("[data-theme-toggle]").click
    expect(page).to have_css("html[data-theme='light']")
    expect(page.evaluate_script("localStorage.getItem('sgu.theme')")).to eq("light")
    expect(page.evaluate_script("location.hash")).to eq("#s-conceito-visual")
    expect(page).to have_css("#s-conceito-visual.is-active")
    expect(visible.call("#s-conceito-visual .apr-figure--hero img")).to contain_exactly(match(/\Alanding-desktop-claro-\h+\.png\z/))
    expect(visible.call("#s-conceito-visual .apr-figure--phone img")).to contain_exactly(match(/\Alanding-mobile-claro-\h+\.png\z/))

    find("#s-conceito-visual .apr-figure--hero .apr-figure__zoom").click
    expect(page).to have_css(".apr-lightbox[open]")
    expect(visible.call(".apr-lightbox img")).to contain_exactly(match(/\Alanding-completa-claro-\h+\.png\z/))
    expect(page.evaluate_script("[...document.querySelectorAll('.apr-lightbox img')].find(image => getComputedStyle(image).display !== 'none').alt")).to include("tema claro")
    press(:escape)
    expect(page).to have_no_css(".apr-lightbox[open]")
  ensure
    page.execute_script("localStorage.removeItem('sgu.theme')")
  end

  it "opens the code evidence by keyboard, keeps focus and slide position, and returns focus on Escape" do
    viewport(1920, 1080)
    visit "#{presentation_path}#s-funcionalidades"
    settle("s-funcionalidades")
    trigger = find("#s-funcionalidades .apr-journey .apr-dialog-btn", match: :first)
    trigger.send_keys(:enter)

    dialog = find("dialog#s-funcionalidades-evidencias-1[open]")
    expect(page.evaluate_script("document.activeElement.id")).to eq("s-funcionalidades-evidencias-1-titulo")
    expect(dialog).to have_css(".apr-evidence__path", text: "app/controllers/alerts_controller.rb")

    press(:arrow_right)
    press(:arrow_right)
    expect(page.evaluate_script("location.hash")).to eq("#s-funcionalidades")
    expect(page).to have_css("#s-funcionalidades.is-active")

    # Fora da janela, só a interface do navegador recebe foco; a página por trás fica inerte.
    focusables = page.evaluate_script("document.querySelectorAll('#s-funcionalidades-evidencias-1 a[href], #s-funcionalidades-evidencias-1 button, #s-funcionalidades-evidencias-1 [tabindex=\"0\"]').length")
    (focusables + 2).times do
      press(:tab)
      expect(page.evaluate_script("document.activeElement === document.body || Boolean(document.activeElement.closest('#s-funcionalidades-evidencias-1'))")).to be(true)
    end
    expect(page.evaluate_script("getComputedStyle(document.querySelector('#s-funcionalidades-evidencias-1 .apr-sheet__body')).overflowY")).to eq("auto")

    press(:escape)
    expect(page).to have_no_css("dialog[open]")
    expect(page.evaluate_script("document.activeElement === arguments[0]", trigger.native)).to be(true)
    expect(page).to have_css("#s-funcionalidades.is-active")
  end

  it "shows secondary details in a popover that closes when the slide changes" do
    viewport(1920, 1080)
    visit "#{presentation_path}#s-funcionalidades"
    settle("s-funcionalidades")
    find("#s-funcionalidades button[aria-label='Sobre: Pânico']").click

    popover = "#s-funcionalidades-extra-0"
    expect(page.evaluate_script("document.querySelector('#{popover}').matches(':popover-open')")).to be(true)
    expect(page).to have_css(popover, text: "ainda não foi homologada")

    find("[data-presentation-target='nextButton']").click
    expect(page).to have_css("#s-retrospectiva.is-active")
    expect(page.evaluate_script("document.querySelector('#{popover}').matches(':popover-open')")).to be(false)
  end

  it "labels conceptual multiplicities inside the canvas and keeps them in the enlarged copy" do
    viewport(1920, 1080)
    visit "#{presentation_path}#s-modelo-conceitual"
    settle("s-modelo-conceitual")
    relations = PresentationDiagram.load_all.fetch("conceptual").relations

    labels = page.evaluate_script(<<~JS)
      (() => {
        const canvas = document.querySelector("#s-modelo-conceitual .apr-data-canvas").getBoundingClientRect();
        return [...document.querySelectorAll("#s-modelo-conceitual .apr-data-cardinality > span")].map(label => {
          const rect = label.getBoundingClientRect();
          return rect.left >= canvas.left - 1 && rect.right <= canvas.right + 1 && rect.top >= canvas.top - 1 && rect.bottom <= canvas.bottom + 1;
        });
      })()
    JS
    expect(labels.size).to eq(relations.size * 2)
    expect(labels).to all(be(true))

    find("#s-modelo-conceitual .apr-data-zoom").click
    expect(page).to have_css(".apr-lightbox[open] .apr-data-cardinality", count: relations.size * 2)
    press(:escape)
    expect(page).to have_css("#s-modelo-conceitual .apr-data-cardinality", count: relations.size * 2)
    expect(page.evaluate_script("document.querySelectorAll('[id=\"s-modelo-conceitual-titulo\"]').length")).to eq(1)
  end


  it "cycles meeting originals with arrows and keyboard without leaving the slide" do
    viewport(1920, 1080)
    visit "#{presentation_path}#s-reunioes"
    settle("s-reunioes")
    expect(page).to have_css(".apr-meeting__featured img[src*='03-rails']")
    find("button[aria-label='Próxima captura']").click
    expect(page).to have_css(".apr-meeting__featured img[src*='04-ambiente']")
    find("button[aria-label='Próxima captura']").click
    expect(page).to have_css(".apr-meeting__featured img[src*='01-painel']")
    find("button[aria-label='Captura anterior']").click
    expect(page).to have_css(".apr-meeting__featured img[src*='04-ambiente']")
    thumb = find(".apr-meeting__thumbnail[data-gallery-index='3']")
    page.execute_script("arguments[0].focus()", thumb.native)
    press(:arrow_left)
    expect(page).to have_css(".apr-meeting__featured img[src*='03-rails']")
    expect(page.evaluate_script("document.activeElement.dataset.galleryIndex")).to eq("2")
    expect(page).to have_css("#s-reunioes.is-active")
    press(:enter)
    expect(page).to have_css(".apr-lightbox[open] img[src*='03-rails']")
    press(:escape)
    expect(page.evaluate_script("document.activeElement.dataset.galleryIndex")).to eq("2")
  end

  it "returns from appendices to the originating main slide with a safe direct-link fallback" do
    create(:presentation_profile, :active, selections: { "modelo-dados" => true })
    viewport(1920, 1080)
    visit "#{presentation_path}#s-modelo-conceitual"
    settle("s-modelo-conceitual")
    find("#s-modelo-conceitual a[href='#s-modelo-dados']").click
    expect(page).to have_css("#s-modelo-dados.is-active")
    find("#s-modelo-dados .apr-appendix-return a").click
    expect(page).to have_css("#s-modelo-conceitual.is-active")
    page.execute_script("location.hash = 's-evolucao'")
    expect(page).to have_css("#s-evolucao.is-active")
    page.execute_script("location.hash = 's-modelo-dados'")
    expect(page).to have_css("#s-modelo-dados.is-active")
    expect(find("#s-modelo-dados .apr-appendix-return a")["href"]).to end_with("#s-evolucao")
    find("#s-modelo-dados .apr-appendix-return a").click
    expect(page).to have_css("#s-evolucao.is-active")
    visit "#{presentation_path}#s-modelo-dados"
    page.driver.browser.navigate.refresh
    expect(page).to have_css("#s-modelo-dados.is-active")
    find("#s-modelo-dados .apr-appendix-return a").click
    expect(page).to have_css("#s-modelo-conceitual.is-active")
    find("button[data-action='presentation#openCustomize']").click
    find("input[data-apr-toggle='modelo-conceitual']").uncheck
    press(:escape)
    origin_id = find(".apr-slide.is-active")["id"]
    page.execute_script("location.hash = 's-modelo-dados'")
    expect(page).to have_css("#s-modelo-dados.is-active")
    expect(find("#s-modelo-dados .apr-appendix-return a")["href"]).to end_with("##{origin_id}")
    find("#s-modelo-dados .apr-appendix-return a").click
    expect(page).to have_css("##{origin_id}.is-active")
  end

  it "changes impact surfaces and the social milestone's full image with the page theme" do
    viewport(1920, 1080)
    visit "#{presentation_path}#s-capa"
    page.execute_script("document.documentElement.dataset.theme = 'dark'; localStorage.setItem('sgu.theme', 'dark')")
    settle("s-capa")
    dark_background = page.evaluate_script("getComputedStyle(document.querySelector('#s-capa')).background")
    find("[data-theme-toggle]").click
    expect(page).to have_css("html[data-theme='light']")
    expect(page.evaluate_script("getComputedStyle(document.querySelector('#s-capa')).background")).not_to eq(dark_background)
    expect(page).to have_css("#s-capa .sgu-brand__on-light", visible: true)
    page.execute_script("location.hash = 's-proximos-passos'")
    settle("s-proximos-passos")
    expect(page).to have_css(".apr-figure--social-post img[src*='post-claro']", visible: true)
    expect(page).to have_no_css(".apr-figure--social-post img[src*='post-escuro']", visible: true)
    find(".apr-figure--social-post .apr-figure__zoom").click
    expect(page).to have_css(".apr-lightbox[open] img[src*='post-claro']", visible: true)
    press(:escape)
    find("[data-theme-toggle]").click
    expect(page).to have_css(".apr-figure--social-post img[src*='post-escuro']", visible: true)
  ensure
    page.execute_script("localStorage.removeItem('sgu.theme')")
  end

  it "prints one page per selected slide without the closed dialogs" do
    visit presentation_path
    pdf = page.driver.browser.send(:bridge).send(:execute, :print_page, {}, {
      orientation: "landscape", page: { width: 21.0, height: 29.7 }, background: true, shrinkToFit: false
    })

    expect(Base64.strict_decode64(pdf).scan(%r{/Type\s*/Page\b(?!s)}).size).to eq(presentation.default_selection.visible_slides.size)
  end
end
