require "rails_helper"

RSpec.describe "Presentation PDF button", type: :feature, js: true do
  it "downloads the current selection and theme without opening the print dialog" do
    visit presentation_path
    expect(page).to have_button("Baixar PDF")
    click_button "Personalizar apresentação"
    find(".apr-custom input[data-apr-toggle='reunioes']").click
    page.driver.browser.action.send_keys(:escape).perform
    page.execute_script(<<~JS)
      document.documentElement.dataset.theme = "light";
      const token = document.createElement("meta");
      token.name = "csrf-token";
      token.content = "pdf-test-csrf-token";
      document.head.append(token);
      window.print = () => { window.printWasCalled = true; };
      window.fetch = (url, options) => {
        window.pdfRequest = { url, body: JSON.parse(options.body), token: options.headers["X-CSRF-Token"] };
        return new Promise(resolve => { window.finishPdf = resolve; });
      };
    JS

    click_button "Baixar PDF"

    expect(page).to have_button("Gerando PDF…", disabled: true)
    request = page.evaluate_script("window.pdfRequest")
    expect(request["url"]).to include("/apresentacao/pdf")
    expect(request.dig("body", "choices", "reunioes")).to be(false)
    expect(request.dig("body", "theme")).to eq("light")
    expect(request["token"]).to eq("pdf-test-csrf-token")
    page.execute_script(<<~JS)
      window.finishPdf(new Response(new Blob(["%PDF-1.7\\nPDF test"]), {
        headers: { "Content-Type": "application/pdf", "Content-Disposition": 'attachment; filename="sgu.pdf"' }
      }));
    JS
    expect(page).to have_button("Baixar PDF", disabled: false)
    expect(page).to have_text("PDF pronto. Download iniciado.")
    expect(page.evaluate_script("window.printWasCalled === true")).to be(false)
  end

  it "shows server errors and lets the user retry" do
    visit presentation_path
    expect(page).to have_button("Baixar PDF")
    page.execute_script(<<~JS)
      window.fetch = () => Promise.resolve(new Response(JSON.stringify({ error: "PDF temporariamente indisponível." }), {
        status: 503, headers: { "Content-Type": "application/json" }
      }));
    JS

    click_button "Baixar PDF"

    expect(page).to have_text("PDF temporariamente indisponível.")
    expect(page).to have_button("Baixar PDF", disabled: false)
  end
end
