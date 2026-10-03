require "rails_helper"

RSpec.describe "Alert correction and photo removal" do
  let(:admin) { create(:user, :admin) }
  let(:author) { create(:user) }

  describe Alerts::CorrectContent do
    let(:alert) { create(:alert, author: author) }

    it "corrects only text and category, with reason and audit, and flags a linked publication" do
      alert.update_columns(requested_visibility: "public_external", visibility: "restricted")
      publication = create(:publication, :published, kind: "occurrence", alert: alert)

      described_class.call(actor: admin, alert: alert.reload, reason: "Dado pessoal", attributes: {
        title: "Título corrigido", latitude: 1, location_source: "manual", reported_severity: "critical", status: "closed"
      })

      expect(alert.reload).to have_attributes(title: "Título corrigido", location_source: "gps", reported_severity: nil, status: "received")
      expect(publication.reload.source_changed_at).to be_present
      expect(AuditEvent.where(subject: alert, action: "alert.content_corrected").pick(:reason)).to eq("Dado pessoal")
    end

    it "is administrative, requires a reason and refuses closed alerts and panics" do
      expect { described_class.call(actor: author, alert: alert, reason: "x", attributes: { title: "Autor tentando" }) }
        .to raise_error(Pundit::NotAuthorizedError)
      expect { described_class.call(actor: admin, alert: alert, reason: " ", attributes: { title: "Sem motivo aqui" }) }
        .to raise_error(ActiveRecord::RecordInvalid)

      alert.update_columns(status: "closed", closed_at: Time.current, closure_reason: "other", closure_notes: "x")
      expect { described_class.call(actor: admin, alert: alert.reload, reason: "x", attributes: { title: "Encerrado" }) }
        .to raise_error(Pundit::NotAuthorizedError)

      panic = create(:alert, :panic)
      expect { described_class.call(actor: admin, alert: panic, reason: "x", attributes: { title: "Pânico" }) }
        .to raise_error(Pundit::NotAuthorizedError)
    end
  end

  describe Alerts::RemovePhoto do
    let(:alert) { Alerts::CreateOccurrence.call(actor: author, attributes: occurrence_attributes, photos: [ photo, photo ]).alert }

    it "removes the attachment in a transaction, audits it and purges the blob only after commit" do
      attachment = alert.photos_attachments.first
      blob = attachment.blob

      purged = []
      allow_any_instance_of(ActiveStorage::Blob).to receive(:purge_later) { |instance| purged << instance.id }
      described_class.call(actor: author, alert: alert, attachment_id: attachment.id, lock_version: alert.lock_version)
      expect(purged).to eq([ blob.id ])

      expect(ActiveStorage::Attachment.exists?(attachment.id)).to be(false)
      expect(AuditEvent.where(subject: alert, action: "alert.photo_removed").pick(:metadata)).to include("photos_count" => 1)
    end

    it "keeps the photo when the transaction fails and never accepts another alert's attachment" do
      attachment = alert.photos_attachments.first
      allow(AuditEvent).to receive(:record!).and_raise(ActiveRecord::RecordInvalid.new(AuditEvent.new))
      expect_any_instance_of(ActiveStorage::Blob).not_to receive(:purge_later)

      expect { described_class.call(actor: author, alert: alert, attachment_id: attachment.id) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(ActiveStorage::Attachment.exists?(attachment.id)).to be(true)

      allow(AuditEvent).to receive(:record!).and_call_original
      other = Alerts::CreateOccurrence.call(actor: create(:user), attributes: occurrence_attributes, photos: [ photo ]).alert
      expect do
        described_class.call(actor: author, alert: alert, attachment_id: other.photos_attachments.first.id)
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "requires authorization, a reason for admins and the current lock_version" do
      attachment = alert.photos_attachments.first

      expect { described_class.call(actor: create(:user), alert: alert, attachment_id: attachment.id) }.to raise_error(Pundit::NotAuthorizedError)
      expect { described_class.call(actor: admin, alert: alert, attachment_id: attachment.id) }.to raise_error(ActiveRecord::RecordInvalid)
      expect { described_class.call(actor: author, alert: alert, attachment_id: attachment.id, lock_version: alert.lock_version - 1) }
        .to raise_error(ActiveRecord::StaleObjectError)
      expect(alert.photos_attachments.count).to eq(2)

      alert.update_columns(status: "triaging")
      expect { described_class.call(actor: author, alert: alert.reload, attachment_id: attachment.id) }.to raise_error(Pundit::NotAuthorizedError)
    end
  end
end
