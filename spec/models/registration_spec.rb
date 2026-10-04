require "rails_helper"

RSpec.describe Registration, type: :model do
  let(:attributes) { { display_name: "Pessoa Fictícia", email_address: "pessoa@ufrpe.br", role_code: "student", password: "Senha123!", password_confirmation: "Senha123!" } }

  it "normalizes the institutional address and name without changing the password" do
    registration = described_class.new(attributes.merge(email_address: " PESSOA@UFRPE.BR ", display_name: " Pessoa   Fictícia "))
    expect(registration).to be_valid
    expect(registration.email_address).to eq("pessoa@ufrpe.br")
    expect(registration.display_name).to eq("Pessoa Fictícia")
    expect(registration.password).to eq("Senha123!")
  end

  [ "pessoa@example.com", "pessoa@aluno.ufrpe.br", "pessoa@ufrpe.br.evil.test", "pessoa@@ufrpe.br", "@ufrpe.br" ].each do |email|
    it "rejects an address outside the exact institution domain: #{email}" do
      registration = described_class.new(attributes.merge(email_address: email))
      expect(registration).not_to be_valid
      expect(registration.errors[:email_address]).not_to be_empty
    end
  end

  %w[security coordination staff resident admin].each do |role|
    it "does not accept privileged or unavailable public roles: #{role}" do
      registration = described_class.new(attributes.merge(role_code: role))
      expect(registration).not_to be_valid
    end
  end

  [ "Curta1!", "senha123!", "SENHA123!", "Senhaaaa!", "Senha1234", "Éa1!" * 19 ].each do |password|
    it "rejects a password missing a requirement or exceeding bcrypt's byte limit: #{password.bytesize}" do
      registration = described_class.new(attributes.merge(password: password, password_confirmation: password))
      expect(registration).not_to be_valid
      expect(registration.errors[:password]).not_to be_empty
    end
  end

  it "requires name, role and matching password confirmation" do
    registration = described_class.new(attributes.merge(display_name: " ", role_code: "", password_confirmation: "Different1!"))
    expect(registration).not_to be_valid
    expect(registration.errors.attribute_names).to include(:display_name, :role_code, :password_confirmation)
  end

  it "prevents case-insensitive duplicate e-mail, including inactive accounts" do
    create(:user, :inactive, email_address: "pessoa@ufrpe.br")
    expect(described_class.new(attributes.merge(email_address: "PESSOA@UFRPE.BR"))).not_to be_valid
  end
end
