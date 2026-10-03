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

  describe "occurrence sources" do
    let!(:public_request) { create(:alert, :public_request, title: "Fonte compatível externa") }
    let!(:restricted) { create(:alert, :restricted, title: "Fonte restrita") }
    let!(:panic) { create(:alert, :panic) }

    it "only offers compatible sources and never panics, restricted or already published alerts" do
      get new_admin_publication_path

      expect(response.body).to include("Fonte compatível externa")
      expect(response.body).not_to include("Fonte restrita")
      expect(response.body).not_to include(panic.protocol)
    end

    it "creates a derived publication without copying the operational description" do
      post admin_publications_path, params: { publication: news_params(kind: "occurrence", alert_id: public_request.id, title: "Queda de árvore no estacionamento") }

      publication = Publication.last
      expect(publication).to have_attributes(kind: "occurrence", alert: public_request)
      expect(publication.body).not_to eq(public_request.description)

      post admin_publications_path, params: { publication: news_params(kind: "occurrence", alert_id: public_request.id) }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects incompatible audiences and panic sources" do
      post admin_publications_path, params: { publication: news_params(kind: "occurrence", alert_id: restricted.id) }
      expect(response).to have_http_status(:unprocessable_entity)

      post admin_publications_path, params: { publication: news_params(kind: "occurrence", alert_id: panic.id) }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "blocks publication after the source changes until a new review" do
      publication = create(:publication, :approved, kind: "occurrence", alert: public_request)
      Alerts::UpdateContent.call(actor: public_request.author, alert: public_request, attributes: { title: "Fonte editada pelo autor" })

      patch publish_admin_publication_path(publication), params: { lock_version: publication.reload.lock_version }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(publication.reload).not_to be_published
    end
  end

  it "is not available to non-admins" do
    sign_in(create(:user))
    post admin_publications_path, params: { publication: news_params }

    expect(response).to redirect_to(panel_path(locale: I18n.locale))
    expect(Publication.count).to eq(0)
  end
end
