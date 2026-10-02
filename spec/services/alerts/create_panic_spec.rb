require "rails_helper"

RSpec.describe Alerts::CreatePanic do
  let(:author) { create(:user) }
  let(:key) { SecureRandom.uuid }

  it "creates a minimal restricted panic without photo, GPS or text" do
    result = described_class.call(actor: author, client_request_id: key)
    alert = result.alert

    expect(result).to be_created
    expect(alert).to have_attributes(
      kind: "panic", visibility: "restricted", requested_visibility: "restricted",
      location_source: "unavailable", location_unavailable_reason: "not_shared", status: "received",
      title: nil, description: nil, category_id: nil, assigned_to_id: nil, reported_severity: nil
    )
    expect(alert.photos).not_to be_attached
  end

  it "does not record human acknowledgement, dispatch or fictitious handling" do
    alert = described_class.call(actor: author, client_request_id: key).alert

    expect(Alert.column_names.grep(/acknowledg|dispatch/)).to be_empty
    expect(alert.status_changed_at).to be_nil
    expect(alert.resolved_at).to be_nil
  end

  it "infers GPS when coordinates are sent and does not set critical severity automatically" do
    alert = described_class.call(actor: author, client_request_id: key,
                                 attributes: { latitude: "-8.0", longitude: "-34.9", location_accuracy_meters: "30" }).alert

    expect(alert.location_source).to eq("gps")
    expect(alert.reported_severity).to be_nil
  end

  it "requires a UUID client key" do
    expect { described_class.call(actor: author) }.to raise_error(ActiveRecord::RecordInvalid)
    expect { described_class.call(actor: author, client_request_id: "123") }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "returns the same alert and protocol on retransmission without new audit events" do
    first = described_class.call(actor: author, client_request_id: key, attributes: { description: "Ajuda" })
    second = described_class.call(actor: author, client_request_id: key.upcase, attributes: { description: "Ajuda" })

    expect(second).not_to be_created
    expect(second.alert).to eq(first.alert)
    expect(second.alert.protocol).to eq(first.alert.protocol)
    expect(Alert.count).to eq(1)
    expect(AuditEvent.where(action: "alert.created").count).to eq(1)
  end

  it "raises a predictable conflict when the same key is reused with different data" do
    described_class.call(actor: author, client_request_id: key, attributes: { description: "Ajuda" })

    expect {
      described_class.call(actor: author, client_request_id: key, attributes: { description: "Outro texto" })
    }.to raise_error(Alerts::Create::IdempotencyConflict)
    expect(Alert.count).to eq(1)
  end

  it "scopes the key per author" do
    described_class.call(actor: author, client_request_id: key)
    other = described_class.call(actor: create(:user), client_request_id: key)

    expect(other).to be_created
    expect(Alert.count).to eq(2)
  end

  it "resolves a concurrent insert of the same key through the unique index" do
    winner = described_class.call(actor: author, client_request_id: key).alert
    service = described_class.new(actor: author, client_request_id: key)
    # Simula a corrida: a primeira leitura não enxerga o registro concorrente ainda não visível.
    calls = 0
    allow(Alert).to receive(:find_by).and_wrap_original do |original, *args, **kwargs|
      calls += 1
      calls == 1 ? nil : original.call(*args, **kwargs)
    end

    result = service.call

    expect(result).not_to be_created
    expect(result.alert).to eq(winner)
    expect(Alert.count).to eq(1)
  end

  it "never accepts social interactions or publications" do
    alert = described_class.call(actor: author, client_request_id: key).alert

    expect { Social::Interactions.subscribe_alert(actor: author, alert: alert) }.to raise_error(Pundit::NotAuthorizedError)
    expect { Publications::Create.call(actor: create(:user, :admin), alert: alert, attributes: { title: "Título qualquer", body: "Texto editorial qualquer", visibility: "internal" }) }
      .to raise_error(ActiveRecord::RecordInvalid, /pânico/)
  end
end
