require "rails_helper"

RSpec.describe PresentationsHelper, type: :helper do
  describe "#presentation_state" do
    it "renders a labelled badge for a known state" do
      html = helper.presentation_state(:aguardando_evidencia)

      expect(html).to include("apr-state--aguardando-evidencia")
      expect(html).to include("Aguardando evidência")
    end

    it "rejects unknown states" do
      expect { helper.presentation_state(:aprovado) }.to raise_error(ArgumentError)
    end
  end

  describe "#presentation_link" do
    it "links public URLs in a new tab" do
      html = helper.presentation_link("GitHub", "https://github.com/lucasact4/engenharia-de-software")

      expect(html).to include('target="_blank"')
      expect(html).to include("noopener")
    end

    it "renders local paths and blanks as plain text" do
      [ 'C:\Users\time\retro.png', "\\\\wsl.localhost\\Ubuntu\\ata.pdf", "file:///tmp/a.png", nil ].each do |url|
        expect(helper.presentation_link("Evidência", url)).not_to include("<a")
      end
    end
  end

  describe "#presentation_duration" do
    it "formats seconds for the script table" do
      expect(helper.presentation_duration(45)).to eq("45s")
      expect(helper.presentation_duration(420)).to eq("7min")
      expect(helper.presentation_duration(395)).to eq("6min35s")
    end
  end
end
