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

    main_slides.each do |slide|
      page.execute_script("location.hash = arguments[0]", slide.dom_id)
      settle(slide.dom_id)
      result = overflow(slide.dom_id)
      expect(result).to eq("vertical" => 0, "horizontal" => 0, "outside" => []), "#{slide.id}: #{result.inspect}"
    end
  end

  it "keeps pages without horizontal scrolling on a phone" do
    viewport(390, 844)
    visit presentation_path

    main_slides.each do |slide|
      page.execute_script("location.hash = arguments[0]", slide.dom_id)
      settle(slide.dom_id)
      expect(overflow(slide.dom_id)["horizontal"]).to eq(0), slide.id
      expect(page.evaluate_script("document.documentElement.scrollWidth <= innerWidth")).to be(true)
    end
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

  it "prints one page per selected slide without the closed dialogs" do
    visit presentation_path
    pdf = page.driver.browser.send(:bridge).send(:execute, :print_page, {}, {
      orientation: "landscape", page: { width: 21.0, height: 29.7 }, background: true, shrinkToFit: false
    })

    expect(Base64.strict_decode64(pdf).scan(%r{/Type\s*/Page\b(?!s)}).size).to eq(presentation.default_selection.visible_slides.size)
  end
end
