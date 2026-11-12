require "rails_helper"

RSpec.describe AnonymousSubmissionAudit, type: :model do
  # RF016: testa o modelo de captura dos metadados implementado por Alisson.
  # Estes exemplos usam o banco de teste para verificar o que foi armazenado
  # e a imutabilidade após persistência. Não usam navegador nem Turnstile real.
  let(:alert) { create(:alert, anonymous_public: true) }
  let(:submitted_at) { Time.utc(2026, 11, 11, 12, 0, 0) }
  let(:ip_address) { "192.0.2.10" }
  let(:user_agent) { "AgentTeste/1.0" }

  # Dados fictícios e controlados: cada caso altera somente a entrada em análise.
  def record_audit(**attributes)
    described_class.record!(**{
      alert: alert, ip_address: ip_address, user_agent: user_agent, submitted_at: submitted_at
    }.merge(attributes))
  end

  describe "RF016 — registro e proteção dos metadados" do
    it "RF016-UT01 registra a auditoria vinculada à ocorrência e ao instante do envio" do
      audit = record_audit.reload

      # O vínculo e a data precisam sobreviver à leitura do banco de teste.
      expect(audit).to be_persisted
      expect(audit.alert_id).to eq(alert.id)
      expect(audit.submitted_at).to eq(submitted_at)
    end

    it "RF016-UT02 armazena o IP cifrado e recupera o valor original pelo leitor" do
      audit = record_audit.reload

      # Compara o conteúdo persistido com a entrada e verifica a recuperação real,
      # sem substituir a criptografia por um mock que poderia esconder defeitos.
      expect(audit.ip_address_ciphertext).to be_present
      expect(audit.ip_address_ciphertext).not_to include(ip_address)
      expect(audit.ip_address).to eq(ip_address)
    end

    it "RF016-UT03 armazena o User-Agent cifrado e recupera o valor original pelo leitor" do
      audit = record_audit.reload

      # O agente do navegador também precisa ser protegido, não somente o IP.
      expect(audit.user_agent_ciphertext).to be_present
      expect(audit.user_agent_ciphertext).not_to include(user_agent)
      expect(audit.user_agent).to eq(user_agent)
    end

    it "RF016-UT04 rejeita uma auditoria sem data e hora da submissão" do
      # Capturar apenas IP e agente não atende ao requisito de registrar o instante.
      expect { record_audit(submitted_at: nil) }.to raise_error(ActiveRecord::RecordInvalid) { |error|
        expect(error.record.errors.of_kind?(:submitted_at, :blank)).to be(true)
      }
      expect(described_class.where(alert: alert)).to be_empty
    end

    it "RF016-UT05 rejeita metadados sem vínculo com uma ocorrência" do
      # Uma auditoria solta não permite identificar a postagem à qual se refere.
      expect { record_audit(alert: nil) }.to raise_error(ActiveRecord::RecordInvalid) { |error|
        expect(error.record.errors.of_kind?(:alert, :blank)).to be(true)
      }
    end

    it "RF016-UT06 impede alterar os metadados de uma auditoria persistida" do
      audit = record_audit

      # Após a tentativa, recarrega para verificar que o banco manteve o original.
      expect { audit.update!(submitted_at: submitted_at + 60) }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect(audit.reload.submitted_at).to eq(submitted_at)
      expect(audit.ip_address).to eq(ip_address)
    end

    it "RF016-UT07 impede excluir uma auditoria persistida pelo modelo" do
      audit = record_audit

      # O registro deve continuar disponível depois da tentativa de destruição.
      # Isso verifica a API do modelo; não afirma proteção contra SQL direto.
      expect { audit.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect(described_class.exists?(audit.id)).to be(true)
      expect(audit.reload.user_agent).to eq(user_agent)
    end
  end
end
