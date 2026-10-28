require "rails_helper"

RSpec.describe "Presentation PDF downloads", type: :request do
  let(:renderer) { instance_double(Presentation::Pdf, call: "%PDF-1.7\nexport") }

  before { allow(Presentation::Pdf).to receive(:new).and_return(renderer) }

  it "downloads an attachment without authentication or changing the profile" do
    profile = create(:presentation_profile, :active)
    original = profile.selections.deep_dup

    post presentation_pdf_path, params: { theme: "light", choices: { "reunioes" => false } }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/pdf")
    expect(response.headers["Content-Disposition"]).to include("attachment", ".pdf")
    expect(response.body).to start_with("%PDF-")
    expect(profile.reload.selections).to eq(original)
    expect(Presentation::Pdf).to have_received(:new).with(hash_including(theme: "light", html: include("data-slide-id")))
  end

  it "renders temporary choices with the requested profile's delivery and required slides" do
    presentation = Presentation.load
    profile = create(:presentation_profile, :active)
    rendered = nil
    allow(Presentation::Pdf).to receive(:new) { |**options| rendered = Nokogiri::HTML(options[:html]); renderer }
    choices = presentation.catalog_keys.index_with { false }

    post presentation_pdf_path(perfil: profile.id), params: { choices: choices }, as: :json

    visible = rendered.css("section.apr-slide:not([hidden])").map { |slide| slide["data-slide-id"] }
    expect(visible).to match_array(Presentation::REQUIRED_SLIDES)
    expect(response).to have_http_status(:ok)
  end

  it "keeps profile choices that are not overridden by the download" do
    create(:presentation_profile, :active, selections: { "escopo" => true })
    rendered = nil
    allow(Presentation::Pdf).to receive(:new) { |**options| rendered = Nokogiri::HTML(options[:html]); renderer }

    post presentation_pdf_path, params: { choices: { "reunioes" => false } }, as: :json

    expect(rendered.at_css("#s-escopo")).not_to have_attribute("hidden")
    expect(rendered.at_css("#s-reunioes")).to have_attribute("hidden")
  end

  it "adds the large linked QR before the cover only in the PDF document" do
    allow(Presentation::Pdf).to receive(:new).and_call_original
    get presentation_path
    web = Nokogiri::HTML(response.body)
    expect(web.at_css(".apr-pdf-access")).to be_nil
    original_ids = web.css(".apr-slide:not([hidden])").map { |slide| slide["id"] }
    public_url = Presentation.load.entrega.dig(:links, :apresentacao)

    pdf = Presentation::Pdf.new(html: response.body, public_url: public_url)
    document = Nokogiri::HTML(pdf.send(:document))

    expect(document.css("#apr-deck > section").first["class"]).to eq("apr-pdf-access")
    expect(document.css(".apr-slide").map { |slide| slide["id"] }).to eq(original_ids)
    access = document.at_css(".apr-pdf-access")
    expect(access.css("a").map { |link| link["href"] }).to all(eq(public_url))
    expect(access.at_css("img")["src"]).to start_with("data:image/png;base64,")
    expect(access.at_css("img")["src"]).to eq(document.at_css("#s-capa .apr-access img")["src"])
    expect(document.at_css("#s-capa .apr-slide__folio").text).to include("01 / ")
  end

  it "rejects arbitrary selection values before starting Chromium" do
    post presentation_pdf_path, params: { choices: { "reunioes" => "https://example.com" } }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(Presentation::Pdf).not_to have_received(:new)
  end

  it "returns an actionable error when another PDF is already being rendered" do
    allow(renderer).to receive(:call).and_raise(Presentation::Pdf::Busy)

    post presentation_pdf_path, as: :json

    expect(response).to have_http_status(:service_unavailable)
    expect(response.headers["Retry-After"]).to eq("10")
    expect(response.parsed_body["error"]).to include("Já há um PDF")
  end

  it "returns a safe error rather than an HTML error page or broken download" do
    allow(renderer).to receive(:call).and_raise(Presentation::Pdf::Error, "renderer disconnected")

    post presentation_pdf_path, as: :json

    expect(response).to have_http_status(:service_unavailable)
    expect(response.media_type).to eq("application/json")
    expect(response.body).not_to include("renderer disconnected")
  end
end
