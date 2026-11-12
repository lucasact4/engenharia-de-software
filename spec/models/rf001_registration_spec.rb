require "rails_helper"

RSpec.describe Registration, type: :model do
  subject(:registration) { described_class.new(attributes) }

  let(:attributes) do
    {
      display_name: "Pessoa de Teste",
      email_address: "teste.rf001@ufrpe.br",
      role_code: "student",
      password: "Senha123!",
      password_confirmation: "Senha123!"
    }
  end

  before do
    allow(User).to receive(:exists?).with(email_address: "teste.rf001@ufrpe.br").and_return(false)
  end

  it "accepts an individual registration without optional identity or contact data" do
    expect(registration).to be_valid
    expect(registration).to have_attributes(person_type: "natural", cpf: nil, mother_name: nil, phone: nil)
  end

  it "requires a business name for a legal entity" do
    registration.assign_attributes(person_type: "legal", business_name: "  ")

    expect(registration).not_to be_valid
    expect(registration.errors.of_kind?(:business_name, :blank)).to be(true)
  end

  it "normalizes a legal entity's business name and formatted identifiers" do
    registration.assign_attributes(
      person_type: "legal",
      business_name: "  Associação   Exemplo  ",
      cnpj: "12.345.678/0001-90",
      phone: "(81) 91234-5678"
    )

    expect(registration).to be_valid
    expect(registration).to have_attributes(
      business_name: "Associação Exemplo",
      cnpj: "12345678000190",
      phone: "81912345678"
    )
  end

  it "requires password confirmation even if the password meets the policy" do
    registration.password_confirmation = ""

    expect(registration).not_to be_valid
    expect(registration.errors.of_kind?(:password_confirmation, :blank)).to be(true)
    expect(registration.errors[:password]).to be_empty
  end
end
