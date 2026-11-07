require "rails_helper"

RSpec.describe "RF008 occurrence follow-up", type: :request do
  let(:author) { create(:user) }
  let(:category) { create(:category) }

  before { sign_in(author) }

  def submit(attributes = {})
    post alerts_path, params: {
      client_request_id: SecureRandom.uuid,
      alert: occurrence_attributes(category: category).merge(attributes)
    }
  end

  describe "completion by the author" do
    %w[received triaging in_progress awaiting_information].each do |status|
      it "resolves an owned #{status} occurrence and records the change without granting handling access" do
        alert = create(:alert, author: author, status: status)
        patch complete_alert_path(alert), params: {
          lock_version: alert.lock_version, status: "closed", priority: "urgent", closure_reason: "invalid"
        }

        expect(response).to redirect_to(alert_path(alert, locale: I18n.locale))
        expect(alert.reload).to have_attributes(status: "resolved", resolved_at: be_present, status_changed_at: be_present,
                                                closed_at: nil, closure_reason: nil, priority: nil)
        event = AuditEvent.for_subject(alert).last
        expect(event).to have_attributes(action: "alert.status_changed", actor: author)
        expect(event.metadata).to include("source" => "author_completion")
        expect(event.changeset.fetch("status")).to eq([ status, "resolved" ])
        expect(AlertPolicy.new(author, alert).transition?).to be(false)

        follow_redirect!
        expect(response.body).to include("Ocorrência resolvida pelo autor")
        expect(response.body).not_to include("Marcar como resolvida")
      end
    end

    it "leaves the linked publication, approval and audience unchanged" do
      alert = Alerts::CreateOccurrence.call(actor: author, attributes: occurrence_attributes(category: category)).alert
      publication = alert.publication
      before = publication.attributes

      patch complete_alert_path(alert), params: { lock_version: alert.lock_version }
      expect(publication.reload.attributes).to eq(before)
    end

    it "accepts a repeated successful request without a second audit event" do
      alert = create(:alert, author: author)
      version = alert.lock_version
      2.times { patch complete_alert_path(alert), params: { lock_version: version } }

      expect(response).to have_http_status(:see_other)
      expect(AuditEvent.for_subject(alert).where(action: "alert.status_changed").count).to eq(1)
    end

    it "requires a version and rejects a concurrent update without changing it" do
      alert = create(:alert, author: author)
      patch complete_alert_path(alert)
      expect(response).to have_http_status(:bad_request)

      stale = alert.lock_version
      alert.update!(description: "Descrição atualizada em outra aba.")
      patch complete_alert_path(alert), params: { lock_version: stale }

      expect(response).to have_http_status(:conflict)
      expect(response.body).to include("Descrição atualizada em outra aba.")
      expect(alert.reload).to have_attributes(status: "received", resolved_at: nil)
      expect(AuditEvent.for_subject(alert)).to be_empty
    end

    it "denies other authors and handlers who do not own the occurrence" do
      alert = create(:alert)
      [ author, create(:user, :admin), create(:user).tap { |user| grant_role(user, :coordination) } ].each do |user|
        sign_in(user)
        patch complete_alert_path(alert), params: { lock_version: alert.lock_version }
        expect(response).to have_http_status(:forbidden)
      end
      expect(alert.reload).to have_attributes(status: "received", resolved_at: nil)
    end

    it "does not expose a restricted occurrence or accept a panic or closed occurrence" do
      hidden = create(:alert, :restricted)
      patch complete_alert_path(hidden), params: { lock_version: hidden.lock_version }
      expect(response).to have_http_status(:not_found)

      panic = create(:alert, :panic, author: author)
      closed = create(:alert, author: author, status: "closed", closed_at: Time.current,
                             closure_reason: "other", closure_notes: "Encerramento administrativo")
      [ panic, closed ].each do |alert|
        patch complete_alert_path(alert), params: { lock_version: alert.lock_version }
        expect(response).to have_http_status(:forbidden)
        expect(AuditEvent.for_subject(alert)).to be_empty
      end
    end

    it "requires authentication" do
      alert = create(:alert, author: author)
      sign_out
      patch complete_alert_path(alert), params: { lock_version: alert.lock_version }
      expect(response).to redirect_to(new_session_path(locale: I18n.locale))
      expect(alert.reload).to have_attributes(status: "received", resolved_at: nil)
    end
  end

  describe "earlier related occurrence" do
    it "creates, edits and removes the reference through the same canonical occurrence" do
      first = create(:alert, :restricted, author: author)
      second = create(:alert, author: author)
      submit(related_alert_id: first.id)
      alert = Alert.order(:id).last
      expect(response).to have_http_status(:see_other)
      expect(alert.related_alert).to eq(first)

      get alert_path(alert)
      expect(response.body).to include(first.protocol)
      get edit_alert_path(alert)
      expect(response.body).to include("Relato anterior")

      publication_id = alert.publication.id
      patch alert_path(alert), params: { lock_version: alert.lock_version, alert: { related_alert_id: second.id } }
      expect(response).to have_http_status(:see_other)
      expect(alert.reload.related_alert).to eq(second)
      expect(alert.publication.id).to eq(publication_id)
      expect(AuditEvent.for_subject(alert).last.metadata.fetch("fields")).to include("related_alert_id")

      patch alert_path(alert), params: { lock_version: alert.lock_version, alert: { related_alert_id: "" } }
      expect(alert.reload.related_alert).to be_nil
    end

    it "rejects nonexistent, foreign and panic references with the same generic error" do
      foreign = create(:alert, :restricted)
      panic = create(:alert, :panic, author: author)
      invalid_ids = [ foreign.id, panic.id, Alert.maximum(:id) + 1000 ]

      invalid_ids.each do |id|
        expect { submit(related_alert_id: id) }.not_to change(Alert, :count)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Relato anterior")
        expect(response.body).not_to include(foreign.protocol, foreign.title, panic.protocol)
      end
    end

    it "rejects self and later references on edit so related reports cannot form a cycle" do
      first = create(:alert, author: author)
      later = create(:alert, author: author, related_alert: first)

      [ first.id, later.id ].each do |id|
        patch alert_path(first), params: { lock_version: first.lock_version, alert: { related_alert_id: id } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(first.reload.related_alert).to be_nil
      end
    end

    it "offers only the author's earlier occurrences and hides the relationship from ordinary readers" do
      prior = create(:alert, :restricted, author: author)
      current = create(:alert, author: author, related_alert: prior)
      later = create(:alert, author: author)
      panic = create(:alert, :panic, author: author)
      foreign = create(:alert, :restricted)
      get edit_alert_path(current)
      expect(response.body).to include(prior.protocol)
      expect(response.body).not_to include(later.protocol, panic.protocol, foreign.protocol)

      sign_in(create(:user))
      get alert_path(current)
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(prior.protocol, "Relato relacionado", "Marcar como resolvida")
    end

    it "does not lose an older reference after the author registers more than 50 occurrences" do
      oldest = create(:alert, author: author)
      create_list(:alert, 51, author: author)
      get new_alert_path
      expect(response.body).to include(oldest.protocol)
    end
  end
end
