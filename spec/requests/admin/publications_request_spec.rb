require "rails_helper"

RSpec.describe "Admin publications", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in(admin) }

  def news_params(overrides = {})
    { kind: "news", title: "Biblioteca em novo horário", body: "A biblioteca central abre às 7h a partir de segunda.",
      visibility: "public_external", comments_enabled: "1" }.merge(overrides)
  end

  it "runs the editorial cycle: draft, review, approval, publication and withdrawal" do
    post admin_publications_path, params: { publication: news_params }
    publication = Publication.last
    expect(publication).to have_attributes(state: "draft", review_status: "not_submitted", author: admin)

    get publication_path(publication)
    expect(response).to have_http_status(:not_found)

    patch submit_review_admin_publication_path(publication)
    patch review_admin_publication_path(publication), params: { decision: "approve", reviewed_content_version: 1, lock_version: publication.reload.lock_version }
    expect(publication.reload).to have_attributes(review_status: "approved", state: "draft")

    get publication_path(publication)
    expect(response).to have_http_status(:not_found)

    patch publish_admin_publication_path(publication), params: { lock_version: publication.lock_version }
    expect(publication.reload).to be_published

    get publication_path(publication)
    expect(response).to have_http_status(:ok)

    patch withdraw_admin_publication_path(publication), params: { reason: "" }
    expect(response).to have_http_status(:unprocessable_entity)
    patch withdraw_admin_publication_path(publication), params: { reason: "Informação desatualizada" }
    expect(publication.reload).to be_withdrawn

    get publication_path(publication)
    expect(response).to have_http_status(:not_found)
  end

  it "rejects only with a reason and refuses approving a version the reviewer did not read" do
    publication = create(:publication, review_status: "pending")

    patch review_admin_publication_path(publication), params: { decision: "reject", reviewed_content_version: 1 }
    expect(response).to have_http_status(:unprocessable_entity)

    publication.update!(content_version: 2)
    patch review_admin_publication_path(publication), params: { decision: "approve", reviewed_content_version: 1, lock_version: publication.lock_version }
    expect(response).to have_http_status(:conflict)
    expect(publication.reload.review_status).to eq("pending")
  end

  it "invalidates the approval and takes content off the air after a relevant edit" do
    publication = create(:publication, :published)

    patch admin_publication_path(publication), params: { lock_version: publication.lock_version, publication: { title: "Título revisto pela equipe" } }

    expect(publication.reload).to have_attributes(state: "draft", review_status: "not_submitted", content_version: 2)
  end

  it "returns 409 and preserves the form for a stale edit" do
    publication = create(:publication)
    stale = publication.lock_version
    publication.update!(body: "Outra pessoa alterou este texto antes.")

    patch admin_publication_path(publication), params: { lock_version: stale, publication: { title: "Meu título que não pode sumir" } }

    expect(response).to have_http_status(:conflict)
    expect(response.body).to include("Meu título que não pode sumir")
  end

  it "requires an expiration for notices before publishing" do
    post admin_publications_path, params: { publication: news_params(kind: "notice") }
    notice = Publication.last
    patch submit_review_admin_publication_path(notice)
    patch review_admin_publication_path(notice), params: { decision: "approve", reviewed_content_version: 1 }
    patch publish_admin_publication_path(notice)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(notice.reload).to be_draft
  end

  describe "occurrences authored by students" do
    let(:student) { create(:user) }
    let(:source) { Alerts::CreateOccurrence.call(actor: student, attributes: occurrence_attributes(requested_visibility: "public_external")).alert }

    it "never offers an occurrence duplication form" do
      get new_admin_publication_path
      expect(response.body).not_to include('name="publication[alert_id]"', 'value="occurrence"')
      get new_admin_publication_path(alert_id: source.id)
      expect(response).to redirect_to(admin_publication_path(source.publication, locale: I18n.locale))
    end

    it "forbids recreating student posts and panic sources" do
      [ source, create(:alert, :restricted), create(:alert, :panic) ].each do |alert|
        expect { post admin_publications_path, params: { publication: news_params(kind: "occurrence", alert_id: alert.id) } }.not_to change(Publication, :count)
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "previews the existing content and approves it in one action" do
      publication = source.publication
      get admin_publication_path(publication)
      expect(response.body).to include(source.description, "Não aprovar")
      expect(response.body).not_to include('name="publication[title]"', 'name="publication[body]"')
      patch review_admin_publication_path(publication), params: { decision: "approve", reviewed_content_version: 1, lock_version: publication.lock_version }
      expect(publication.reload).to have_attributes(state: "published", visibility: "public_external")
    end

    it "requires a rejection reason and keeps a revised post internal pending another review" do
      publication = source.publication
      patch review_admin_publication_path(publication), params: { decision: "reject", reviewed_content_version: 1 }
      expect(response).to have_http_status(:unprocessable_entity)
      patch review_admin_publication_path(publication), params: { decision: "reject", reason: "Remova os dados pessoais", reviewed_content_version: 1 }
      expect(publication.reload).to have_attributes(state: "published", visibility: "internal", review_status: "rejected")
      Alerts::UpdateContent.call(actor: student, alert: source, attributes: { description: "Novo relato sem dados pessoais de terceiros." })
      expect(publication.reload).to have_attributes(state: "published", visibility: "internal", review_status: "pending", content_version: 2)
      patch publish_admin_publication_path(publication)
      expect(response).to have_http_status(:forbidden)
    end
  end

  it "is not available to non-admins" do
    sign_in(create(:user))
    post admin_publications_path, params: { publication: news_params }

    expect(response).to redirect_to(panel_path(locale: I18n.locale))
    expect(Publication.count).to eq(0)
  end
end
