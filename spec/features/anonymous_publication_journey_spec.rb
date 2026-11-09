require "rails_helper"

RSpec.describe "Authenticated concealed-identity submission", type: :feature, js: true do
  let!(:category) { create(:category, name: "Infraestrutura") }
  let(:author) { create(:user, :public_profile, display_name: "Autora Reservada", username: "autora_reservada") }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("TURNSTILE_SITE_KEY").and_return("test-site-key")
    allow(ENV).to receive(:[]).with("TURNSTILE_SECRET_KEY").and_return("test-secret")
  end

  def install_test_widget
    page.execute_script(<<~JS)
      window.testWidgetRemovals = [];
      window.testWidgetRenders = 0;
      window.turnstile = {
        render(container, options) {
          const input = document.createElement("input");
          input.type = "hidden";
          input.name = options["response-field-name"] || "cf-turnstile-response";
          input.value = "browser-test-token";
          container.append(input);
          options.callback();
          return window.testWidgetRenders++;
        },
        remove(id) { window.testWidgetRemovals.push(id); }
      };
    JS
  end

  it "submits the widget's standard field through server verification and conceals the public identity" do
    admin = create(:user, :admin)
    author.update!(verified_at: Time.current, verified_by: admin)
    response = Net::HTTPOK.new("1.1", "200", "OK")
    allow(response).to receive(:body).and_return({
      success: true, action: "anonymous_occurrence", hostname: URI(Capybara.app_host).host
    }.to_json)
    http = instance_double(Net::HTTP)
    allow(http).to receive(:use_ssl=).with(true)
    allow(http).to receive(:open_timeout=).with(3)
    allow(http).to receive(:read_timeout=).with(3)
    allow(Net::HTTP).to receive(:new).and_call_original
    allow(Net::HTTP).to receive(:new).with("challenges.cloudflare.com", 443).and_return(http)
    allow(http).to receive(:start).and_yield(http)
    expect(http).to receive(:request) do |request|
      expect(URI.decode_www_form(request.body)).to include([ "response", "browser-test-token" ])
      response
    end

    sign_in_via_ui author
    visit new_alert_path
    expect(page).to have_content("O registro exige uma conta")
    fill_in "Título", with: "Relato com identidade protegida"
    fill_in "Descrição", with: "Há um problema na iluminação do corredor."
    select "Infraestrutura", from: "Categoria"
    choose "Informar o local", allow_label_click: true
    fill_in "Descrição do local", with: "Corredor do bloco de aulas"
    select "Todos (pública)", from: "Quem pode ver"
    install_test_widget

    check "Ocultar minha identidade no mural"
    expect(page).to have_content("Desafio confirmado.")
    expect(page).to have_css('input[name="cf-turnstile-response"]', visible: :all, count: 1)
    uncheck "Ocultar minha identidade no mural"
    expect(page).to have_no_css('input[name="cf-turnstile-response"]', visible: :all)
    expect(page.evaluate_script("window.testWidgetRemovals")).to eq([ 0 ])
    check "Ocultar minha identidade no mural"
    expect(page).to have_css('input[name="cf-turnstile-response"]', visible: :all, count: 1)
    click_button "Publicar ocorrência"
    expect(page).to have_content("Ocorrência registrada.")

    alert = Alert.order(:id).last
    expect(alert).to have_attributes(author: author, anonymous_public: true)
    expect(alert.anonymous_submission_audit).to be_present
    publication = alert.publication
    expect(publication).to be_public_external
    Capybara.reset_sessions!
    visit publication_path(publication)
    expect(page).to have_content("Pessoa anônima")
    expect(page).to have_no_content(author.display_name)
    expect(page).to have_no_link(author.username)

    visit publications_path
    fill_in "Criador", with: author.display_name
    find('button[aria-label="Buscar"]').click
    expect(page).to have_current_path(/creator=/)
    expect(page).to have_content("Nada encontrado com esses filtros.")
    expect(page).to have_no_css("article.social-post", text: alert.title)
  end

  it "conceals an unverified author's identity from internal readers while external approval is pending" do
    result = Alerts::CreateOccurrence.call(actor: author,
      attributes: occurrence_attributes(category: category, requested_visibility: "public_external", anonymous_public: true),
      request_audit: { ip_address: "192.0.2.1", user_agent: "RF005-test", submitted_at: Time.current })
    post = result.alert.publication
    expect(post).to have_attributes(visibility: "internal", review_status: "pending")

    sign_in_via_ui create(:user)
    visit publication_path(post)
    expect(page).to have_content("Pessoa anônima")
    expect(page).to have_no_content(author.display_name)
    visit publications_path
    fill_in "Criador", with: author.username
    find('button[aria-label="Buscar"]').click
    expect(page).to have_current_path(/creator=/)
    expect(page).to have_content("Nada encontrado com esses filtros.")
    expect(page).to have_no_css("article.social-post", text: result.alert.title)
  end
end
