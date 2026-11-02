require "rails_helper"

# Revisão da 2ª entrega: retrospectiva real, capturas por tema, evidências do código e marca SGU.
RSpec.describe "Presentation revision and SGU brand", type: :request do
  let(:document) { Nokogiri::HTML(response.body) }
  let(:presentation) { Presentation.load }
  let(:retro_link) { "https://app.funretrospectives.com/session/-P348lsyv9l5kgdtJO7_" }

  describe "retrospective" do
    it "shows the real board with alt text and opens the session safely in a new tab" do
      get presentation_path
      slide = document.at_css("#s-retrospectiva")

      image = slide.at_css(".apr-figure--board img")
      expect(image["src"]).to include("presentation/retrospectiva/quadro-gostei-aprendi-faltou")
      expect(image["alt"]).to include("Gostei", "Aprendi", "Faltou")
      expect(slide.at_css(".apr-figure--board .apr-figure__zoom")["data-zoom-src"]).to include("quadro-gostei-aprendi-faltou")

      links = slide.css("a[href='#{retro_link}']")
      expect(links.size).to eq(2)
      expect(links.map { |link| [ link["target"], link["rel"] ] }).to all(eq([ "_blank", "noopener noreferrer" ]))
      expect(slide.text).to include("Abrir retrospectiva", "app.funretrospectives.com/session/-P348lsyv9l5kgdtJO7_", "4 cartões")
      expect(slide.text).not_to include("A data da dinâmica não foi registrada", "Captura real do quadro")
      expect(slide.css("iframe")).to be_empty
    end

    it "shares the lessons data while showing only the supplied Aprendi crop" do
      get presentation_path
      lessons = document.at_css("#s-status-report")

      expect(lessons.css(".apr-lesson__title").map(&:text)).to eq(presentation.retrospective.lessons.map(&:title))
      expect(lessons.css(".apr-lessons__chips li")).to be_empty
      expect(lessons.text).not_to include("Para melhorar", "transcritos do quadro", "Quadro completo")
      expect(lessons.at_css(".apr-figure--lessons img")["src"]).to include("retrospectiva/aprendi")
      expect(lessons.at_css("a[href='#{retro_link}']")).to be_present
      expect(lessons.at_css("a[href='#s-retrospectiva']")).to be_present
    end

    it "keeps the first-delivery reflection slide working with points, actions and lessons" do
      create(:presentation_profile, :active, delivery: "primeira", selections: { "retrospectiva.pontos" => true, "retrospectiva.acoes" => true, "retrospectiva.licoes" => true })
      get presentation_path
      slide = document.at_css("#s-retrospectiva")

      expect(slide.text).to include("Reflexão da equipe sobre o período", "Tecnologia completa", "Evolução contínua")
      expect(slide.text).to include("Nenhuma ação com responsável e prazo foi formalizada")
    end
  end

  describe "visual concept" do
    it "renders dark and light captures with their own enlarged images and alt texts" do
      get presentation_path
      hero = document.at_css("#s-conceito-visual .apr-figure--hero")

      images = hero.css(".apr-figure__zoom img")
      expect(images.map { |image| image["data-theme"] }).to eq(%w[dark light])
      expect(images.map { |image| image["class"] }).to eq([ "apr-figure__img apr-theme-only--dark", "apr-figure__img apr-theme-only--light" ])
      expect(images.map { |image| image["data-zoom-src"] }).to match([ /landing-completa-\h+\.png/, /landing-completa-claro-\h+\.png/ ])
      expect(images.map { |image| image["alt"] }).to match([ /tema escuro/, /tema claro/ ])
      expect(document.css("#s-conceito-visual .apr-figure__img").size).to eq(6)
      expect(document.at_css("#s-conceito-visual .apr-palette").text).to include("#153C36", "#226A5C", "#93DBC4", "#F2BD57", "#0D171A", "#F4F7F5")
    end

    it "keeps secondary notes behind a labelled information button" do
      get presentation_path
      button = document.at_css("#s-conceito-visual .apr-shots__notes button.apr-info")

      expect(button["aria-label"]).to eq("Sobre as capturas")
      popover = document.at_css("##{button['popovertarget']}")
      expect(popover["popover"]).to eq("")
      expect(popover.text).to include("/entrar", "390 × 844 px", "exemplos estáticos")
    end
  end

  describe "GitHub and the two functionalities" do
    it "keeps both configured journeys with a short summary and a dialog of real evidence" do
      get presentation_path
      slide = document.at_css("#s-funcionalidades")

      expect(slide.css(".apr-journey__name").map(&:text)).to eq([ "Registrar ocorrência e acompanhar o atendimento", "Publicar e interagir no mural" ])
      expect(slide.css(".apr-journey__summary").map(&:text)).to eq([
        "A pessoa registra a ocorrência; a equipe atende; o autor acompanha a situação.",
        "A comunidade publica, comenta, responde, curte, salva e acompanha."
      ])
      expect(slide.css(".apr-journey .apr-evidence__path").reject { |node| node.ancestors("dialog").any? }).to be_empty

      presentation.funcionalidades[:itens].each_with_index do |item, index|
        button = slide.css(".apr-journey .apr-dialog-btn")[index]
        dialog = document.at_css("dialog##{button['commandfor']}")
        expect(button["command"]).to eq("show-modal")
        expect(button["aria-haspopup"]).to eq("dialog")
        expect(dialog["aria-labelledby"]).to eq("#{dialog['id']}-titulo")
        expect(dialog.css(".apr-evidence__path").map(&:text)).to eq(item[:evidencias].map { |evidence| evidence[:caminho] })
        expect(dialog.css(".apr-sheet__tests code").map(&:text)).to eq(item[:testes])
        published = item[:evidencias].select { |evidence| evidence[:publicado] }
        expect(dialog.css("a[href*='github.com']").map { |link| link["href"] }).to eq(published.map { |evidence| presentation.evidence_url(evidence) })
        expect(published.size).to eq(item[:evidencias].size)
        expect(dialog.text).not_to include("Somente na cópia local", "aceite da equipe")
        expect(dialog.text).not_to match(%r{/home/|/workspaces/|@ufrpe\.br|password})
      end
    end

    it "shows the original GitHub capture with a link to the repository" do
      get presentation_path
      column = document.at_css("#s-funcionalidades .apr-repo-shot")

      expect(column.at_css("img")["src"]).to include("presentation/github/repositorio")
      expect(column.text).not_to include("Será anexada pela equipe")
      expect(column.at_css("a[href='https://github.com/lucasact4/engenharia-de-software']").text).to include("Abrir repositório")
    end

    it "explains a configured capture that is not in the assets yet" do
      data = presentation
      data.funcionalidades[:repositorio][:captura] = "presentation/github/inexistente.png"
      data.funcionalidades[:itens].first[:evidencias].first[:captura] = "presentation/github/controller.png"
      allow(Presentation).to receive(:load).and_return(data)

      get presentation_path

      expect(document.at_css("#s-funcionalidades .apr-repo-shot").text).to include("Arquivo configurado não encontrado")
      expect(document.at_css("#s-funcionalidades-evidencias-1").text).to include("Captura configurada não encontrada")
      expect(document.css("#s-funcionalidades img[src*='inexistente'], #s-funcionalidades img[src*='controller.png']")).to be_empty
    end

    it "lists the extras with honest states and accessible explanations" do
      get presentation_path
      extras = document.css("#s-funcionalidades .apr-extra")

      expect(extras.map { |extra| extra.at_css(".apr-extra__name").text }).to eq([ "Pânico", "Aprovação pública", "Selo de verificado", "Moderação", "Cadastro e perfis" ])
      expect(extras.first.text).to include("Parcial", "ainda não foi homologada")
      expect(extras.last.text).to include("Parcial", "confirmação de e-mail ainda não foi implementada")
      expect(extras.css("button.apr-info").map { |button| button["aria-label"] }).to all(start_with("Sobre: "))
    end
  end


  describe "refinement content" do
    it "keeps short titles and makes the full GitHub requirement available separately" do
      get presentation_path
      expect(document.at_css("#s-funcionalidades .apr-title").text).to eq("GitHub e duas funcionalidades completas")
      button = document.at_css("#s-funcionalidades .apr-title-row button")
      expect(document.at_css("##{button['popovertarget']}").text).to include("contemplando as 2 funcionalidades")
      expect(document.at_css("#s-status-report .apr-title").text).to eq("O que aprendemos nesse sprint")
      expect(document.at_css("#s-capa .sgu-brand--horizontal")).to be_present
      expect(document.at_css("#s-capa .apr-cover__sigla")).to be_nil
    end

    it "orders eleven milestones without distracting links or approval notices" do
      get presentation_path
      timeline = document.at_css("#s-evolucao")
      expect(timeline.css(".apr-history a")).to be_empty
      dates = timeline.css(".apr-history time").map { |node| node["datetime"] }
      expect(dates.size).to eq(11)
      expect(dates).to eq(dates.sort)
      expect(timeline.at_css("time[datetime='2026-09-30']")["title"]).to include("Data estimada")
      expect(document.text).not_to include("aceite da equipe", "Validação da equipe pendente", "Somente na cópia local", "itens confirmados pela equipe")
    end

    it "shows both original post themes with five separate future priorities" do
      get presentation_path
      slide = document.at_css("#s-proximos-passos")
      expect(slide.css(".apr-figure--social-post img").map { |img| img['data-theme'] }).to eq(%w[dark light])
      expect(slide.css(".apr-steps__title").map(&:text)).to eq([ "Mapear requisitos e evolução", "Simular os e-mails de desenvolvimento", "Cadastrar os locais da UFRPE", "Testar e refinar a experiência", "Melhorar usabilidade e participação" ])
      expect(slide.text).to include("letter_opener")
      expect(slide.text).not_to include("Fechar os diagramas pendentes", "Publicar e ensaiar", "Riscos", "Dependências")
    end
  end

  describe "presentation access" do
    it "returns appendices to a visible slide when the first delivery hides the conceptual model" do
      create(:presentation_profile, :active, delivery: "primeira", selections: { "modelo-dados" => true, "modelo-conceitual" => false })
      get presentation_path
      expect(document.at_css("#s-modelo-conceitual").has_attribute?("hidden")).to be(true)
      expect(document.css(".apr-appendix-return a").map { |link| link["href"] }.uniq).to eq([ "#s-capa" ])
    end

    it "uses the configured public origin for QR and image links in PDF exports" do
      get presentation_path
      public_url = presentation.entrega.dig(:links, :apresentacao)
      expect(document.at_css("#s-capa .apr-access a")["href"]).to eq(public_url)
      expect(document.at_css("#s-capa .apr-access img")["src"]).to include("presentation/acesso/apresentacao-qr")
      links = document.css(".apr-figure__open").map { |node| node["href"] }
      expect(links).not_to be_empty
      expect(links).to all(start_with("https://sgu.lucasact4.com.br/assets/"))
    end
  end

  describe "SGU brand" do
    let(:brand_pattern) { %r{brand/sgu-(simbolo|logo-horizontal|logo-vertical)} }

    it "replaces the template identity on public, authentication and presentation pages" do
      [ root_path, new_session_path, new_registration_path, presentation_path ].each do |path|
        get path
        expect(response.body).to match(brand_pattern), "marca ausente em #{path}"
        expect(response.body).not_to match(/logo-proposito|Prop[oó]sito Digital/i)
      end
    end

    it "brands the portal header and the administration sidebar, including the collapsed state" do
      sign_in(create(:user))
      get panel_path
      expect(document.at_css("header a[aria-label='SGU UFRPE, início'] .sgu-brand--symbol")).to be_present
      expect(document.at_css("header a[aria-label='SGU UFRPE, início'] .sgu-brand--horizontal")).to be_present
      expect(response.body).to include("Equipe UFRPE de Engenharia de Software")

      sign_out
      sign_in(create(:user, :admin))
      get admin_path
      admin = Nokogiri::HTML(response.body)
      expect(admin.at_css(".admin-sidebar-logo-full .sgu-brand--horizontal")).to be_present
      expect(admin.at_css(".admin-sidebar-logo-mini .sgu-brand--symbol")).to be_present
    end

    it "uses the SGU icons in the page head and in the web manifest template" do
      get root_path
      expect(document.css("link[rel='icon']").map { |link| link["href"] }).to include("/icon.png", "/icon.svg")
      expect(Rails.root.join("public/icon.svg").read).to include("SGU")

      manifest = JSON.parse(ApplicationController.render(template: "pwa/manifest", formats: :json, layout: false))
      expect(manifest).to include("short_name" => "SGU", "theme_color" => "#153C36")
      expect(manifest["icons"].map { |icon| icon["src"] }).to eq([ "/icon.png", "/icon-maskable.png" ])
    end
  end
end
