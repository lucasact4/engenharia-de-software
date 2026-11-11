require "rails_helper"

RSpec.describe ContentReport, type: :model do
  # RF013 — Denunciar postagens: este spec verifica as regras da classe ContentReport.
  # build_stubbed prepara associações com IDs sem gravá-las. As denúncias também
  # não são salvas, portanto os callbacks de notificação não são executados.
  # O Rails e o banco de teste ainda são usados pelas validações de unicidade.
  let(:reporter) { build_stubbed(:user) }
  let(:publication) { build_stubbed(:publication) }
  let(:comment) { build_stubbed(:comment, publication: publication) }

  # Parte de uma denúncia válida de publicação por spam. Cada caso altera apenas
  # os dados necessários à regra que deseja verificar, mantendo o restante válido.
  def report_with(**attributes)
    described_class.new({ reporter: reporter, publication: publication, reason: "spam" }.merge(attributes))
  end

  # Os IDs UT01 a UT11 relacionam estes exemplos aos critérios do plano de teste.
  # be_valid chama valid?; nos casos negativos, verificamos também o tipo do erro
  # para evitar que o teste passe por uma falha diferente daquela que procuramos.
  describe "RF013 — critérios de aceitação das denúncias" do
    it "RF013-UT01 aceita uma denúncia direcionada somente a uma publicação" do
      # Cenário válido: o usuário informa uma publicação, sem comentário como alvo.
      report = report_with

      # A denúncia deve ser válida e identificar a publicação como conteúdo denunciado.
      expect(report).to be_valid
      expect(report.target).to eq(publication)
    end

    it "RF013-UT02 aceita uma denúncia direcionada somente a um comentário" do
      # Retira o alvo padrão para que somente o comentário seja denunciado.
      report = report_with(publication: nil, comment: comment)

      # Além do comentário correto, deve ser possível localizar sua publicação
      # de origem, usada pelos controles de acesso ao conteúdo denunciado.
      expect(report).to be_valid
      expect(report.target).to eq(comment)
      expect(report.target_publication).to eq(publication)
    end

    it "RF013-UT03 rejeita uma denúncia sem conteúdo denunciado" do
      # Sem publicação e sem comentário, não há conteúdo para a equipe analisar.
      report = report_with(publication: nil)

      # single_target é um erro geral da denúncia, por isso fica em :base.
      expect(report).not_to be_valid
      expect(report.errors.of_kind?(:base, :single_target)).to be(true)
    end

    it "RF013-UT04 rejeita uma denúncia com publicação e comentário simultâneos" do
      # Mantém a publicação padrão e acrescenta um comentário: dois alvos.
      report = report_with(comment: comment)

      # Mesmo que o comentário pertença à publicação, cada denúncia deve ter
      # exatamente um alvo; os dois juntos tornam o registro ambíguo.
      expect(report).not_to be_valid
      expect(report.errors.of_kind?(:base, :single_target)).to be(true)
    end

    it "RF013-UT05 rejeita uma denúncia sem denunciante" do
      # Mantém alvo e motivo válidos, retirando somente a pessoa que denuncia.
      report = report_with(reporter: nil)

      # A associação com o denunciante é obrigatória. Esta validação de modelo
      # não substitui os testes de autenticação e autorização da requisição.
      expect(report).not_to be_valid
      expect(report.errors.of_kind?(:reporter, :blank)).to be(true)
    end

    it "RF013-UT06 rejeita um motivo que não pertence às opções permitidas" do
      # Simula um valor que não existe no enum, como em uma entrada manipulada.
      report = report_with(reason: "unsupported")

      # A validação deve indicar motivo fora da lista, e não aceitar texto arbitrário.
      expect(report).not_to be_valid
      expect(report.errors.of_kind?(:reason, :inclusion)).to be(true)
    end

    it "RF013-UT07 exige uma explicação quando o motivo é Outro" do
      # Outro é uma opção válida, mas precisa explicar o problema à moderação.
      report = report_with(reason: "other", details: nil)

      # O erro esperado é a ausência de detalhes, não um motivo inválido.
      expect(report).not_to be_valid
      expect(report.errors.of_kind?(:details, :blank)).to be(true)
    end

    it "RF013-UT08 rejeita espaços, quebra de linha e tabulação como explicação de Outro" do
      # Um campo aparentemente preenchido só com caracteres em branco continua vazio.
      report = report_with(reason: "other", details: "  \n\t  ")

      # A normalização não pode permitir que esses caracteres contornem a exigência.
      expect(report).not_to be_valid
      expect(report.errors.of_kind?(:details, :blank)).to be(true)
    end

    it "RF013-UT09 aceita Outro com explicação e remove os espaços externos" do
      # Contraponto aos dois casos anteriores: há uma explicação de fato,
      # acompanhada de espaços extras no começo e no fim.
      report = report_with(reason: "other", details: "  O conteúdo expõe dados pessoais.  ")

      # Deve aceitar a denúncia e preservar o texto, removendo apenas espaços externos.
      expect(report).to be_valid
      expect(report.details).to eq("O conteúdo expõe dados pessoais.")
    end

    it "RF013-UT10 aceita uma explicação com exatamente 2.000 caracteres" do
      # Testa o limite superior permitido com tamanho literal, para que uma
      # mudança indevida na constante do modelo seja detectada pelo teste.
      report = report_with(details: "a" * 2000)

      # O limite é inclusivo: exatamente 2.000 caracteres ainda é uma entrada válida.
      expect(report).to be_valid
    end

    it "RF013-UT11 rejeita uma explicação com 2.001 caracteres" do
      # Testa o primeiro tamanho inválido, imediatamente acima do limite.
      report = report_with(details: "a" * 2001)

      # Junto ao caso anterior, detecta erros de comparação na fronteira de tamanho.
      expect(report).not_to be_valid
      expect(report.errors.of_kind?(:details, :too_long)).to be(true)
    end
  end
end
