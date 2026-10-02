require "rails_helper"

RSpec.describe "Alert handling services" do
  let(:admin) { create(:user, :admin) }
  let(:coordinator) { create(:user).tap { |user| grant_role(user, :coordination) } }
  let(:guard) { create(:user).tap { |user| grant_role(user, :security) } }
  let(:alert) { create(:alert) }

  describe Alerts::Assess do
    it "records assessed severity and priority without replacing the reported severity" do
      alert.update!(reported_severity: "low")

      Alerts::Assess.call(actor: coordinator, alert: alert, attributes: { assessed_severity: "high", priority: "urgent" },
                          reason: "Risco de queda")

      expect(alert.reload).to have_attributes(reported_severity: "low", assessed_severity: "high", priority: "urgent")
      event = AuditEvent.for_subject(alert).last
      expect(event).to have_attributes(action: "alert.assessed", actor: coordinator, reason: "Risco de queda")
      expect(event.changeset).to eq("assessed_severity" => [ nil, "high" ], "priority" => [ nil, "urgent" ])
    end

    it "denies authors and users without handling roles" do
      expect { Alerts::Assess.call(actor: alert.author, alert: alert, attributes: { priority: "high" }) }
        .to raise_error(Pundit::NotAuthorizedError)
      professor = create(:user).tap { |user| grant_role(user, :professor) }
      expect { Alerts::Assess.call(actor: professor, alert: alert, attributes: { priority: "high" }) }
        .to raise_error(Pundit::NotAuthorizedError)
    end

    it "detects concurrent edits through lock_version" do
      stale_version = alert.lock_version
      Alerts::Assess.call(actor: admin, alert: Alert.find(alert.id), attributes: { priority: "low" })

      expect {
        Alerts::Assess.call(actor: admin, alert: Alert.find(alert.id), attributes: { priority: "high" }, lock_version: stale_version)
      }.to raise_error(ActiveRecord::StaleObjectError)
    end
  end

  describe Alerts::Assign do
    it "assigns an eligible active person and audits it" do
      Alerts::Assign.call(actor: coordinator, alert: alert, assignee: guard)

      expect(alert.reload.assigned_to).to eq(guard)
      expect(AuditEvent.for_subject(alert).last.changeset).to eq("assigned_to_id" => [ nil, guard.id ])
    end

    it "rejects inactive or non-eligible assignees" do
      expect { Alerts::Assign.call(actor: admin, alert: alert, assignee: create(:user)) }
        .to raise_error(ActiveRecord::RecordInvalid)
      inactive = create(:user, :inactive).tap { |user| grant_role(user, :coordination) }
      expect { Alerts::Assign.call(actor: admin, alert: alert, assignee: inactive) }
        .to raise_error(ActiveRecord::RecordInvalid)
    end

    it "lets security handle an occurrence directly assigned to them" do
      expect(AlertPolicy.new(guard, alert).handle?).to be(false)
      Alerts::Assign.call(actor: admin, alert: alert, assignee: guard)

      expect(AlertPolicy.new(guard, alert.reload).handle?).to be(true)
    end
  end

  describe Alerts::Transition do
    def transition(to, actor: coordinator, **options)
      Alerts::Transition.call(actor: actor, alert: alert, to: to, **options)
    end

    it "follows the provisional matrix and records timestamps" do
      transition("triaging")
      transition("in_progress")
      transition("resolved")

      expect(alert.reload).to have_attributes(status: "resolved", resolved_at: be_present, status_changed_at: be_present)
      transition("closed")
      expect(alert.reload).to have_attributes(status: "closed", closure_reason: "resolved", closed_at: be_present)
    end

    it "does not require visiting every state but rejects skips outside the matrix" do
      expect { transition("resolved") }.to raise_error(Alerts::Transition::InvalidTransition)
      transition("closed", closure_reason: "invalid", closure_notes: "Registro de teste")

      expect(alert.reload.resolved_at).to be_nil
    end

    it "requires explanation for invalid, out of scope or other closures" do
      expect { transition("closed", closure_reason: "out_of_scope") }.to raise_error(ActiveRecord::RecordInvalid)
      expect(alert).to have_attributes(status: "received", closed_at: nil)
      expect(alert.errors).to include(:closure_notes)
      expect { transition("closed", closure_reason: "resolved") }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "closes as duplicate only with an accessible target" do
      original = create(:alert)
      transition("closed", closure_reason: "duplicate", duplicate_of: original)

      expect(alert.reload.duplicate_of).to eq(original)

      hidden = create(:alert, :panic)
      other = create(:alert)
      expect {
        Alerts::Transition.call(actor: coordinator, alert: other, to: "closed", closure_reason: "duplicate", duplicate_of: hidden)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "requires a reason to reopen and only admins reopen closed alerts" do
      transition("triaging")
      transition("in_progress")
      transition("resolved")

      expect { transition("in_progress") }.to raise_error(ActiveRecord::RecordInvalid)
      transition("in_progress", reason: "Problema voltou")
      expect(alert.reload.resolved_at).to be_nil

      transition("closed", closure_reason: "other", closure_notes: "Encerrado pela coordenação")
      expect { transition("triaging", reason: "Reabrir") }.to raise_error(Pundit::NotAuthorizedError)

      transition("triaging", actor: admin, reason: "Nova evidência")
      expect(alert.reload).to have_attributes(status: "triaging", closure_reason: nil, closed_at: nil, closure_notes: nil)
      expect(AuditEvent.for_subject(alert).last.metadata).to include("reopening" => true)
    end

    it "does not publish anything when resolving" do
      transition("triaging")
      transition("in_progress")
      transition("resolved")

      expect(Publication.count).to eq(0)
    end
  end

  describe Alerts::UpdateContent do
    it "lets the author edit while received and flags the linked publication without rewriting it" do
      public_alert = create(:alert, :public_request)
      publication = create(:publication, :published, kind: "occurrence", alert: public_alert)

      Alerts::UpdateContent.call(actor: public_alert.author, alert: public_alert, attributes: { description: "Descrição corrigida pelo autor." })

      expect(publication.reload.body).to eq("Texto editorial revisado para os testes.")
      expect(publication.source_changed_at).to be_present
      expect(publication).to be_published
      expect { Publications::Publish.call(actor: admin, publication: publication) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "is denied after triage started or to other people" do
      expect { Alerts::UpdateContent.call(actor: create(:user), alert: alert, attributes: { title: "Outro título" }) }
        .to raise_error(Pundit::NotAuthorizedError)
      Alerts::Transition.call(actor: admin, alert: alert, to: "triaging")
      expect { Alerts::UpdateContent.call(actor: alert.author, alert: alert, attributes: { title: "Outro título" }) }
        .to raise_error(Pundit::NotAuthorizedError)
    end
  end

  describe Alerts::ChangeAudience do
    it "lets the author restrict and withdraws the linked publication in the same transaction" do
      public_alert = create(:alert, :public_request)
      publication = create(:publication, :published, kind: "occurrence", alert: public_alert)

      Alerts::ChangeAudience.call(actor: public_alert.author, alert: public_alert, requested_visibility: "restricted")

      expect(publication.reload).to be_withdrawn
      expect(PublicationPolicy::Scope.new(nil, Publication.all).resolve).to be_empty
      expect(AuditEvent.for_subject(publication).last.metadata).to include("system_reason" => "source_audience_changed")
    end

    it "does not let the author expand the audience" do
      restricted = create(:alert, :restricted)

      expect { Alerts::ChangeAudience.call(actor: restricted.author, alert: restricted, requested_visibility: "internal") }
        .to raise_error(Pundit::NotAuthorizedError)
      Alerts::ChangeAudience.call(actor: admin, alert: restricted, requested_visibility: "internal", reason: "Pedido do autor")
      expect(restricted.reload).to have_attributes(visibility: "internal", requested_visibility: "internal")
    end

    it "lets admins restrict an internal alert keeping the original request" do
      Alerts::Restrict.call(actor: admin, alert: alert, reason: "Dados pessoais no texto")

      expect(alert.reload).to have_attributes(visibility: "restricted", requested_visibility: "internal")
      expect(AlertPolicy::Scope.new(create(:user), Alert.all).resolve).not_to include(alert)
    end
  end
end
