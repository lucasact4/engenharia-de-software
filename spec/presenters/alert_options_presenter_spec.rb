require "rails_helper"

RSpec.describe AlertOptionsPresenter do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  it "returns value, label, description and disabled for every option" do
    create(:category, name: "Infraestrutura", description: "Prédios e iluminação")
    contract = described_class.new(actor: user).to_h

    contract.each_value do |options|
      options.each { |option| expect(option.keys).to eq(%i[value label description disabled]) }
    end
    expect(contract[:kinds].map { |o| o[:label] }).to eq(%w[Ocorrência Pânico])
    expect(contract[:categories].first).to include(label: "Infraestrutura", description: "Prédios e iluminação", disabled: false)
  end

  it "reads enum values from the model mapping and labels from I18n" do
    presenter = described_class.new(actor: user)

    expect(presenter.statuses.map(&:value)).to eq(Alert.statuses.values)
    expect(presenter.reported_severities.map(&:label)).to eq(%w[Leve Moderada Alta Crítica])
    I18n.with_locale(:en) { expect(presenter.reported_severities.map(&:label)).to eq(%w[Low Moderate High Critical]) }
  end

  it "shows an inactive category already associated as unavailable without losing it" do
    inactive = create(:category, active: false, name: "Antiga")
    create(:category, name: "Ativa")
    alert = create(:alert, category: create(:category))
    alert.update_columns(category_id: inactive.id)

    options = described_class.new(actor: admin, alert: alert.reload).categories
    expect(options.map(&:label)).to include("Ativa", "Antiga")
    expect(options.find { |o| o.label == "Antiga" }.disabled).to be(true)
    expect(described_class.new(actor: user).categories.map(&:label)).not_to include("Antiga")
  end

  it "limits panic options and occurrence location sources" do
    presenter = described_class.new(actor: user)

    expect(presenter.requested_visibilities(kind: "panic").map(&:value)).to eq(%w[restricted])
    expect(presenter.location_sources(kind: "occurrence").map(&:value)).to eq(%w[gps map manual])
    expect(presenter.location_unavailable_reasons(kind: "occurrence")).to be_empty
  end

  it "filters priority, assessment and transitions by actor" do
    alert = create(:alert)

    expect(described_class.new(actor: alert.author, alert: alert).priorities).to be_empty
    expect(described_class.new(actor: alert.author, alert: alert).transitions).to be_empty
    expect(described_class.new(actor: admin, alert: alert).priorities.map(&:value)).to eq(%w[low normal high urgent])
    expect(described_class.new(actor: admin, alert: alert).transitions.map(&:value)).to eq(%w[triaging closed])
  end

  it "does not offer reopening of closed alerts to coordination" do
    coordinator = create(:user).tap { |u| grant_role(u, :coordination) }
    alert = create(:alert, status: "closed", closed_at: Time.current, closure_reason: "other", closure_notes: "Teste")

    expect(described_class.new(actor: coordinator, alert: alert).transitions).to be_empty
    expect(described_class.new(actor: admin, alert: alert).transitions.map(&:value)).to eq(%w[triaging])
  end

  it "does not expose private data or counts" do
    create(:alert, :restricted, title: "Segredo operacional")

    expect(described_class.new(actor: user).to_h.to_s).not_to include("Segredo operacional")
  end
end
