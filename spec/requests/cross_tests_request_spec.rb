require "rails_helper"

RSpec.describe "Cross testing pages", type: :request do
  let(:testing) { Presentation::CrossTesting.load }

  it "shows the tester recommendations without authentication" do
    get cross_tests_path

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    expect(page.at_css("h1").text).to eq("Teste o SGU")
    expect(page.css(".apr-xt-mission").size).to eq(testing.missoes.size)
    expect(page.at_css("a.apr-xt-url")["href"]).to eq(testing.mvp[:url])
    expect(page.css(".apr-xt-out li").size).to eq(testing.fora_do_escopo.size)
  end

  it "shows the test plan linked to the requirements document" do
    get test_plan_path

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    expect(page.at_css("h1").text).to eq("Plano de teste")
    expect(page.css(".apr-plan-table tbody tr").size).to eq(testing.missoes.size)
    doc_url = Presentation.load.requisitos.dig(:documento, :url)
    expect(page.css(".apr-plan-meta a").map { |link| link["href"] }).to include(doc_url)
    expect(page.at_css("a[href='#{test_plan_pdf_path}']")).to be_present
  end

  it "lists the implementation summary PDF right below the official requirements document" do
    requisitos = Presentation.load.requisitos
    official = requisitos.dig(:documento, :url)
    implementation = requisitos.dig(:documento_implementacao, :url)
    expect(Rails.public_path.join(implementation.delete_prefix("/"))).to exist

    get cross_tests_path
    links = Nokogiri::HTML(response.body).css("a.apr-xt-doc").map { |link| link["href"] }
    expect(links.first(2)).to eq([ official, implementation ])

    get test_plan_path
    links = Nokogiri::HTML(response.body).css(".apr-plan-docs a").map { |link| link["href"] }
    expect(links).to eq([ official, implementation ])
  end

  it "downloads the test plan as a portrait document PDF" do
    renderer = instance_double(Presentation::Pdf, call: "%PDF-1.7\nplan")
    allow(Presentation::Pdf).to receive(:new).and_return(renderer)

    get test_plan_pdf_path

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/pdf")
    expect(response.headers["Content-Disposition"]).to include("attachment", "sgu-plano-de-teste.pdf")
    expect(Presentation::Pdf).to have_received(:new)
      .with(hash_including(layout: :document, theme: "light", html: include("apr-plan")))
  end

  it "returns to the plan with a message when the PDF cannot be generated" do
    renderer = instance_double(Presentation::Pdf)
    allow(renderer).to receive(:call).and_raise(Presentation::Pdf::Busy)
    allow(Presentation::Pdf).to receive(:new).and_return(renderer)

    get test_plan_pdf_path

    expect(response).to redirect_to(test_plan_path)
    follow_redirect!
    expect(response.body).to include("Já há um PDF sendo gerado")
  end

  it "builds the document PDF without the slide access page or the top bar" do
    get test_plan_path
    pdf = Presentation::Pdf.new(html: response.body, theme: "light", public_url: testing.mvp[:url], layout: :document)
    document = Nokogiri::HTML(pdf.send(:document))

    expect(document.at_css("body")["class"]).to include("apr-pdf--doc")
    expect(document.at_css(".apr-pdf-access")).to be_nil
    expect(document.at_css(".apr-bar")).to be_nil
    expect(document.at_css("a[href$='/apresentacao/testes-cruzados']")["href"]).to start_with("https://")
  end

  it "offers both pages as optional slides of the presentation" do
    presentation = Presentation.load
    complementary = presentation.slide_groups(presentation.default_delivery).to_h { |id, _, slides| [ id, slides.map(&:id) ] }

    expect(complementary.fetch("complementar")).to include("testes-cruzados", "plano-de-teste")

    create(:presentation_profile, :active, selections: { "testes-cruzados" => true, "plano-de-teste" => true })
    get presentation_path
    page = Nokogiri::HTML(response.body)
    expect(page.at_css("#s-testes-cruzados")).not_to have_attribute("hidden")
    expect(page.at_css("#s-plano-de-teste a[href='#{test_plan_path}']")).to be_present
  end
end
