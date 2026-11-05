require "rails_helper"

RSpec.describe Alerts::Complete do
  let(:alert) { create(:alert) }

  it "rolls back resolution when its audit cannot be saved" do
    event = AuditEvent.new
    event.errors.add(:action, "audit unavailable")
    allow(AuditEvent).to receive(:record!).and_raise(ActiveRecord::RecordInvalid.new(event))

    expect {
      described_class.call(actor: alert.author, alert: alert, lock_version: alert.lock_version)
    }.to raise_error(ActiveRecord::RecordInvalid)
    expect(alert.reload).to have_attributes(status: "received", resolved_at: nil, status_changed_at: nil)
  end

  it "rechecks the current record under lock instead of completing an occurrence closed by another actor" do
    stale = Alert.find(alert.id)
    alert.update!(status: "closed", closed_at: Time.current, closure_reason: "other", closure_notes: "Equipe encerrou")

    expect {
      described_class.call(actor: stale.author, alert: stale, lock_version: stale.lock_version)
    }.to raise_error(Pundit::NotAuthorizedError)
    expect(alert.reload).to have_attributes(status: "closed", resolved_at: nil)
  end

  it "denies completion by an inactive author" do
    author = alert.author
    author.update!(deleted_at: Time.current)

    expect {
      described_class.call(actor: author, alert: alert, lock_version: alert.lock_version)
    }.to raise_error(Pundit::NotAuthorizedError)
  end
end
