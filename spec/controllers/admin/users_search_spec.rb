require "rails_helper"

RSpec.describe Admin::UsersController, "RF002 — pesquisa de pessoas", type: :controller do
  def buscar_pessoas(termo)
    allow(controller).to receive(:params)
      .and_return(ActionController::Parameters.new(term: termo))

    controller.send(:apply_term_filter, User.all)
  end

  it "localiza pelo nome, razão social, nome da mãe e e-mail" do
    pessoa = create(:user, display_name: "Ana Maria Pessoa", business_name: "Empresa Girassol",
                           mother_name: "Maria de Souza", email_address: "ana.pessoa@example.com")

    termos = [ "Ana Maria", "Girassol", "Maria de Souza", "ana.pessoa@example.com" ]
    resultados = termos.map { |termo| buscar_pessoas(termo).exists?(id: pessoa.id) }

    expect(resultados).to all(be(true))
  end

  it "encontra nomes com busca parcial sem diferenciar maiúsculas e minúsculas" do
    pessoa = create(:user, display_name: "Beatriz Nascimento")

    expect(buscar_pessoas("NASCIMENTO").ids).to include(pessoa.id)
  end

  it "pesquisa CPF e CNPJ exatos mesmo quando o termo está formatado" do
    pessoa_fisica = create(:user, cpf: "12345678901")
    pessoa_juridica = create(:user, person_type: "legal", business_name: "Comércio Exemplo",
                                   cnpj: "12345678000195")

    expect(buscar_pessoas("123.456.789-01").ids).to contain_exactly(pessoa_fisica.id)
    expect(buscar_pessoas("12.345.678/0001-95").ids).to contain_exactly(pessoa_juridica.id)
  end

  it "não encontra documentos por um trecho numérico parcial" do
    pessoa = create(:user, cpf: "98765432100", email_address: "pessoa.sem.documento@example.com")

    expect(buscar_pessoas("43210").ids).not_to include(pessoa.id)
  end
end
