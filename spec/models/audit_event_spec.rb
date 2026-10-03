require "rails_helper"

RSpec.describe AuditEvent do
  let(:admin) { create(:user, :admin) }
  let(:alert) { create(:alert, reported_severity: "low") }

  it "stores only allowlisted fields and metadata" do
    event = described_class.record!(
      actor: admin, action: "alert.status_changed", subject: alert,
      changes: { "status" => %w[received triaging], "description" => [ "texto antigo", "texto novo" ],
                 "latitude" => [ -8.0, -8.1 ], "password_digest" => %w[a b] },
      metadata: { kind: "occurrence", token: "segredo", email: "x@example.com" }
    )

    expect(event.changeset).to eq("status" => %w[received triaging])
    expect(event.metadata).to eq("kind" => "occurrence")
  end

  it "is append-only through the model API" do
    event = described_class.record!(actor: admin, action: "alert.assessed", subject: alert)

    expect { event.update!(action: "alterado") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { event.destroy }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect(event.reload.action).to eq("alert.assessed")
  end

  it "requires an actor except for identified technical events and recognized subject types" do
    expect { described_class.record!(actor: nil, action: "alert.assessed", subject: alert) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(described_class.record!(actor: nil, action: "system.bootstrap", subject: alert)).to be_persisted
    expect { described_class.record!(actor: admin, action: "category.updated", subject: create(:category)) }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "is written in the same transaction as the change" do
    allow(described_class).to receive(:record!).and_raise(ActiveRecord::RecordInvalid)

    expect { Alerts::Assess.call(actor: admin, alert: alert, attributes: { priority: "high" }) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(alert.reload.priority).to be_nil
  end
end
