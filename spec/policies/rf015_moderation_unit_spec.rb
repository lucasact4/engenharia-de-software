require "rails_helper"

RSpec.describe PublicationPolicy do
  let(:publication) { instance_double(Publication) }

  it "RF015-U01 permite que administrador ativo gerencie publicações" do
    admin = instance_double(User, active?: true, admin?: true)

    expect(described_class.new(admin, publication).manage?).to be(true)
  end

  it "RF015-U02 impede que usuário comum gerencie publicações" do
    member = instance_double(User, active?: true, admin?: false)

    expect(described_class.new(member, publication).manage?).to be(false)
  end

  it "RF015-U03 impede que administrador inativo gerencie publicações" do
    inactive_admin = instance_double(User, active?: false, admin?: true)

    expect(described_class.new(inactive_admin, publication).manage?).to be(false)
  end

  it "RF015-U04 impede que visitante gerencie publicações" do
    expect(described_class.new(nil, publication).manage?).to be(false)
  end
end
