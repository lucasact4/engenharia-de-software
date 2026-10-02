require "rails_helper"
require Rails.root.join("db/migrate/20261001120200_bootstrap_roles_and_categories")

RSpec.describe Catalogs::Bootstrap do
  it "creates the seven roles and seven categories idempotently" do
    expect(described_class.call).to eq(roles: 7, categories: 7)
    expect(described_class.call).to eq(roles: 0, categories: 0)

    expect(Role.ordered.pluck(:name)).to eq(%w[Segurança Coordenação Professor Estudante Funcionário Visitante Morador])
    expect(Category.ordered.pluck(:name)).to eq([ "Infraestrutura", "Segurança", "Clima e ambiente", "Mobilidade e trânsito",
                                                  "Serviços e utilidades", "Limpeza e saneamento", "Outro" ])
    expect(Category.find_by(code: "other").requires_details).to be(true)
    expect(Location.count).to eq(0)
  end

  it "does not overwrite edited labels nor reactivate entries" do
    described_class.call
    Category.find_by(code: "security").update!(name: "Segurança patrimonial", active: false)
    described_class.call

    expect(Category.find_by(code: "security")).to have_attributes(name: "Segurança patrimonial", active: false)
  end

  it "matches the frozen copy in the bootstrap migration" do
    expect(described_class::ROLES).to eq(BootstrapRolesAndCategories::ROLES)
    expect(described_class::CATEGORIES).to eq(BootstrapRolesAndCategories::CATEGORIES)
    expect(described_class::ROLES.map(&:first)).to match_array(Role::RECOGNIZED_CODES)
  end

  it "does not touch user accounts" do
    user = create(:user, :admin)

    expect { described_class.call }.not_to change { user.reload.attributes }
  end
end
