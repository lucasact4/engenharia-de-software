require "rails_helper"
require "axe-rspec"

# RNF008: telas principais sem violações automáticas das regras WCAG 2.1 nível A e AA (axe-core),
# nos temas escuro (padrão) e claro. Teste manual com teclado e leitor de tela complementa esta checagem.
RSpec.describe "RNF008 — acessibilidade WCAG 2.1 AA nas telas principais", type: :feature, js: true do
  WCAG = %i[wcag2a wcag2aa wcag21a wcag21aa].freeze

  def expect_accessible_in_both_themes(path)
    %w[dark light].each do |theme|
      visit path
      page.execute_script("localStorage.setItem('sgu.theme', arguments[0])", theme)
      visit path
      aggregate_failures("tema #{theme} em #{path}") { expect(page).to be_axe_clean.according_to(*WCAG) }
    end
  end

  context "sem login" do
    it("início") { expect_accessible_in_both_themes(root_path) }
    it("entrar") { expect_accessible_in_both_themes(new_session_path) }
    it("mural") { expect_accessible_in_both_themes(publications_path) }
    it("mapa do campus") { expect_accessible_in_both_themes(campus_map_path) }
  end

  context "como estudante" do
    let(:student) { create(:user).tap { |user| grant_role(user, :student) } }

    before { sign_in_via_ui(student) }

    it("registrar ocorrência") { expect_accessible_in_both_themes(new_alert_path) }
    it("pânico") { expect_accessible_in_both_themes(new_panic_path) }
    it("minhas ocorrências") { expect_accessible_in_both_themes(alerts_path) }
  end

  context "como segurança" do
    let(:officer) { create(:user).tap { |user| grant_role(user, :security) } }

    before { sign_in_via_ui(officer) }

    it("fila de atendimento") { expect_accessible_in_both_themes(handling_alerts_path) }
  end
end
