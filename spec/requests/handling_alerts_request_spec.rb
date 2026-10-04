require "rails_helper"

RSpec.describe "Handling queue", type: :request do
  let(:coordinator) { create(:user).tap { |user| grant_role(user, :coordination) } }
  let(:security) { create(:user).tap { |user| grant_role(user, :security) } }
  let(:admin) { create(:user, :admin) }
  let(:author) { create(:user) }
  let!(:alert) { create(:alert, :restricted, author: author, title: "Vazamento no laboratório") }

  describe "access" do
    it "is denied to people without handling roles and hides the menu link" do
      sign_in(create(:user))

      get handling_alerts_path
      expect(response).to have_http_status(:forbidden)

      get panel_path
      expect(response.body).not_to include(handling_alerts_path(locale: I18n.locale))
    end

    it "lists occurrences for coordination and opens restricted ones they handle" do
      sign_in(coordinator)

      get handling_alerts_path
      expect(response.body).to include("Vazamento no laboratório")

      get handling_alert_path(alert)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Classificação")
    end

    it "shows security only panic alerts and what is assigned to them" do
      sign_in(security)

      get handling_alerts_path
      expect(response.body).not_to include("Vazamento no laboratório")
      get handling_alert_path(alert)
      expect(response).to have_http_status(:not_found)

      alert.update_columns(assigned_to_id: security.id)
      get handling_alert_path(alert)
      expect(response).to have_http_status(:ok)
    end

    it "revalidates a revoked role on the next request" do
      sign_in(coordinator)
      coordinator.roles.update_all(active: false)

      get handling_alert_path(alert)
      expect(response).to have_http_status(:not_found)
    end

    it "filters inside the authorized scope" do
      create(:alert, :panic)
      sign_in(coordinator)

      get handling_alerts_path(kind: "panic", status: "todas")
      expect(response.body).to include("Nenhum registro nesta fila")

      get handling_alerts_path(priority: "unclassified", sort: "prioridade", q: "vazamento")
      expect(response.body).to include("Vazamento no laboratório")
    end
  end

  describe "assessment and assignment" do
    before { sign_in(coordinator) }

    it "saves severity and priority separately from the reported severity" do
      alert.update_columns(reported_severity: "low")
      patch assessment_handling_alert_path(alert), params: { lock_version: alert.lock_version, assessed_severity: "high", priority: "urgent" }

      expect(alert.reload).to have_attributes(reported_severity: "low", assessed_severity: "high", priority: "urgent")
      expect(AuditEvent.where(subject: alert, action: "alert.assessed")).to exist
    end

    it "returns 409 for a stale lock_version and keeps the submitted values" do
      stale = alert.lock_version
      alert.update!(priority: "low")

      patch assessment_handling_alert_path(alert), params: { lock_version: stale, assessed_severity: "critical", priority: "urgent", reason: "Motivo digitado" }

      expect(response).to have_http_status(:conflict)
      expect(alert.reload.priority).to eq("low")
      expect(response.body).to include("Motivo digitado")
      expect(response.body).to include("Outra pessoa atualizou este alerta")
    end

    it "only assigns eligible active accounts" do
      patch assignment_handling_alert_path(alert), params: { lock_version: alert.lock_version, assigned_to_id: security.id }
      expect(alert.reload.assigned_to).to eq(security)

      inactive = create(:user, :inactive).tap { |user| grant_role(user, :coordination) }
      patch assignment_handling_alert_path(alert), params: { lock_version: alert.reload.lock_version, assigned_to_id: inactive.id }
      expect(response).to have_http_status(:unprocessable_entity)

      plain = create(:user)
      patch assignment_handling_alert_path(alert), params: { lock_version: alert.reload.lock_version, assigned_to_id: plain.id }
      expect(response).to have_http_status(:unprocessable_entity)

      patch assignment_handling_alert_path(alert), params: { lock_version: alert.reload.lock_version, assigned_to_id: "999999" }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(alert.reload.assigned_to).to eq(security)
    end
  end

  describe "transitions" do
    before { sign_in(coordinator) }

    def transition(params)
      patch transition_handling_alert_path(alert), params: { lock_version: alert.reload.lock_version }.merge(params)
    end

    it "follows the matrix and rejects forbidden jumps" do
      transition(to: "resolved")
      expect(response).to have_http_status(:unprocessable_entity)
      expect(alert.reload.status).to eq("received")

      transition(to: "triaging")
      transition(to: "in_progress")
      transition(to: "resolved")
      expect(alert.reload).to have_attributes(status: "resolved", resolved_at: be_present)
    end

    it "requires closure reason and notes when applicable" do
      transition(to: "closed")
      expect(response).to have_http_status(:unprocessable_entity)

      transition(to: "closed", closure_reason: "invalid")
      expect(response).to have_http_status(:unprocessable_entity)
      expect(alert.reload.status).to eq("received")

      transition(to: "closed", closure_reason: "invalid", closure_notes: "Relato sem relação com o campus.")
      expect(alert.reload).to have_attributes(status: "closed", closure_reason: "invalid")
    end

    it "validates duplicate references without revealing inaccessible alerts" do
      hidden = create(:alert, :panic)
      original = create(:alert)

      transition(to: "closed", closure_reason: "duplicate", duplicate_protocol: hidden.protocol)
      expect(response).to have_http_status(:unprocessable_entity)
      hidden_error = response.body[/sgu-field-error[^<]*</]
      transition(to: "closed", closure_reason: "duplicate", duplicate_protocol: "SGU-AAAAA-AAAAA")
      expect(response.body[/sgu-field-error[^<]*</]).to eq(hidden_error)

      transition(to: "closed", closure_reason: "duplicate", duplicate_protocol: alert.protocol)
      expect(response).to have_http_status(:unprocessable_entity)

      transition(to: "closed", closure_reason: "duplicate", duplicate_protocol: original.protocol.downcase)
      expect(alert.reload).to have_attributes(status: "closed", duplicate_of: original)
    end

    it "requires a reason to reopen a resolved alert and reserves closed reopening to admins" do
      alert.update_columns(status: "resolved", resolved_at: Time.current)

      transition(to: "in_progress")
      expect(response).to have_http_status(:unprocessable_entity)
      transition(to: "in_progress", reason: "Problema voltou a acontecer.")
      expect(alert.reload.status).to eq("in_progress")

      alert.update_columns(status: "closed", closed_at: Time.current, closure_reason: "other", closure_notes: "x", resolved_at: nil)
      get handling_alert_path(alert)
      expect(response.body).to include("só podem ser reabertos pela administração")
      transition(to: "triaging", reason: "Tentativa")
      expect(response).to have_http_status(:forbidden)
      expect(alert.reload.status).to eq("closed")

      sign_in(admin)
      patch transition_admin_alert_path(alert), params: { lock_version: alert.lock_version, to: "triaging", reason: "Reaberto pela administração." }
      expect(alert.reload).to have_attributes(status: "triaging", closure_reason: nil)
    end

    it "shows the author only the allowed history" do
      transition(to: "triaging", reason: "Triagem iniciada")
      patch assessment_handling_alert_path(alert), params: { lock_version: alert.reload.lock_version, priority: "high", reason: "Nota interna da equipe" }

      sign_in(author)
      get alert_path(alert)
      expect(response.body).to include("Triagem iniciada")
      expect(response.body).not_to include("Nota interna da equipe")
      expect(response.body).not_to include(coordinator.email_address)

      reader = create(:user)
      Alert.where(id: alert.id).update_all(requested_visibility: "internal", visibility: "internal")
      sign_in(reader)
      get alert_path(alert)
      expect(response.body).not_to include("Triagem iniciada")
      expect(response.body).to include("Situação alterada")
    end
  end
end
