require "rails_helper"

RSpec.describe Presentation::Retrospective do
  let(:presentation) { Presentation.load }

  def build(data)
    described_class.new(ActiveSupport::HashWithIndifferentAccess.new(data))
  end

  it "reads the real board, keeping the session link exactly as recorded" do
    retro = presentation.retrospective

    expect(retro.link).to eq("https://app.funretrospectives.com/session/-P348lsyv9l5kgdtJO7_")
    expect(retro.image).to eq("presentation/retrospectiva/quadro-gostei-aprendi-faltou.png")
    expect(Rails.root.join("app/assets/images", retro.image)).to exist
    expect(retro.columns.map(&:title)).to eq(%w[Gostei Aprendi Faltou])
    expect(retro.columns.map { |column| column.cards.size }).to eq([ 4, 4, 4 ])
    expect(retro.date).to be_blank
    expect(retro.actions).to be_empty
  end

  it "feeds the lessons slide from the Aprendi column and the gaps from Faltou" do
    retro = presentation.retrospective

    expect(retro.lessons.map(&:title)).to eq([ "Experiência prática", "Escolhas técnicas", "Da ideia à prática", "Evolução contínua" ])
    expect(retro.gaps.map(&:title)).to eq([ "Base antes do código", "Requisitos mais claros", "Ordem das tarefas", "Tempo e organização" ])
    expect(retro.points.map(&:title)).to include("Tecnologia completa", "Tempo e organização")
  end

  it "keeps the previous format working" do
    retro = build(pontos: [ "Divisão por card" ], licoes: [ "Testar cedo" ], acoes: [ { acao: "Revisar PRs", responsavel: "Equipe", prazo: "sexta" } ])

    expect(retro.columns).to be_empty
    expect(retro.lessons.map(&:text)).to eq([ "Testar cedo" ])
    expect(retro.points.map(&:text)).to eq([ "Divisão por card" ])
    expect(retro.actions.first).to have_attributes(text: "Revisar PRs", owner: "Equipe", deadline: "sexta")
    expect(retro.gaps).to be_empty
    expect(retro).to be_registered
  end

  it "treats an empty record as pending" do
    expect(build({})).not_to be_registered
  end

  it "rejects links that are not public https addresses and malformed columns" do
    expect { build(link: "file:///tmp/retro.png").validate! }.to raise_error(ArgumentError, /https/)
    expect { build(colunas: [ { id: "gostei", titulo: "A", cartoes: [] }, { id: "gostei", titulo: "B", cartoes: [] } ]).validate! }
      .to raise_error(ArgumentError, /id único/)
    expect { build(colunas: [ { id: "aprendi", titulo: "Aprendi", cartoes: [ { titulo: "Sem texto" } ] } ]).validate! }
      .to raise_error(ArgumentError, /cartões com texto/)
  end
end
