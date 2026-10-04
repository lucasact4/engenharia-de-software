require "rails_helper"

RSpec.describe "Mural (publications)", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:reader) { create(:user) }
  let!(:external) { create(:publication, :published, title: "Comunicado externo") }
  let!(:internal) { create(:publication, :published, visibility: "internal", title: "Comunicado interno") }
  let!(:draft) { create(:publication, title: "Rascunho editorial") }
  let!(:expired) { create(:publication, :published, title: "Aviso vencido", kind: "notice", expires_at: 1.minute.from_now) }

  before { expired.update_columns(expires_at: 1.minute.ago) }

  it "shows anonymous visitors only current external publications" do
    get publications_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Comunicado externo")
    expect(response.body).not_to include("Comunicado interno")
    expect(response.body).not_to include("Rascunho editorial")
    expect(response.body).not_to include("Aviso vencido")
    expect(response.body).to include("Entre para interagir")

    get publication_path(internal)
    expect(response).to have_http_status(:not_found)
  end

  it "shows internal publications to active accounts and never drafts, even to admins" do
    sign_in(admin)

    get publications_path
    expect(response.body).to include("Comunicado interno")
    expect(response.body).not_to include("Rascunho editorial")

    get publication_path(draft)
    expect(response).to have_http_status(:not_found)
  end

  it "never exposes operational data of the source alert" do
    source = create(:alert, :public_request, description: "Relato aprovado para a comunidade")
    publication = create(:publication, :published, kind: "occurrence", alert: source, title: "Ocorrência divulgada", body: "Texto editorial revisado sobre a ocorrência.")

    get publication_path(publication)

    expect(response.body).to include("Relato aprovado para a comunidade")
    expect(response.body).not_to include(source.latitude.to_s, source.longitude.to_s)
    expect(response.body).not_to include(source.protocol)
    expect(response.body).not_to include(source.author.email_address)
    expect(response.body).not_to include("/fotos/")
  end

  it "searches and filters within the visible scope" do
    sign_in(reader)

    get publications_path(q: "comunicado", audience: "internal")
    expect(response.body).to include("Comunicado interno")
    expect(response.body).not_to include("Comunicado externo")

    get publications_path(kind: "notice")
    expect(response.body).not_to include("Aviso vencido")
  end

  it "keeps the feed query count stable as publications grow (no N+1)" do
    sign_in(reader)
    get publications_path
    count_for = lambda do
      queries = 0
      callback = ->(*, payload) { queries += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION]) || payload[:cached] }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { get publications_path }
      queries
    end

    baseline = count_for.call
    8.times { |index| create(:publication, :published, title: "Extra #{index}").tap { |p| create(:comment, publication: p) } }
    expect(count_for.call).to be <= baseline + 1
  end

  describe "interactions" do
    before { sign_in(reader) }

    it "likes, saves and follows with explicit idempotent POST/DELETE" do
      2.times { post publication_like_interaction_path(external) }
      2.times { post publication_bookmark_interaction_path(external) }
      post publication_subscription_interaction_path(external)

      expect(PublicationLike.where(user: reader).count).to eq(1)
      expect(PublicationBookmark.where(user: reader).count).to eq(1)
      expect(PublicationSubscription.where(user: reader).count).to eq(1)

      2.times { delete publication_like_interaction_path(external) }
      expect(PublicationLike.where(user: reader).count).to eq(0)
    end

    it "answers Turbo Stream requests with the refreshed action bar" do
      post publication_like_interaction_path(external), headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("publication_#{external.id}_actions")
      expect(response.body).to include('aria-pressed="true"')
    end

    it "refuses new interactions after withdrawal but lets people remove their own links" do
      post publication_bookmark_interaction_path(external)
      Publications::Withdraw.call(actor: admin, publication: external, reason: "Retirada")

      post publication_like_interaction_path(external)
      expect(response).to have_http_status(:not_found)
      expect(PublicationLike.count).to eq(0)

      get saved_publications_path
      expect(response.body).not_to include("Comunicado externo")
      expect(response.body).to include("não está mais disponível")

      delete publication_bookmark_interaction_path(external)
      expect(PublicationBookmark.count).to eq(0)
      expect(response).to redirect_to(saved_publications_path(locale: I18n.locale))
    end

    it "takes the user from the session, ignoring user_id params" do
      other = create(:user)
      post publication_like_interaction_path(external), params: { user_id: other.id }

      expect(PublicationLike.pluck(:user_id)).to eq([ reader.id ])
    end

    it "rejects unknown interaction kinds from the route" do
      post "/mural/#{external.id}/curtida", params: { kind: "admin" }

      expect(PublicationLike.where(user: reader).count).to eq(1)
    end
  end

  it "requires login to interact and remembers the publication to return to" do
    post publication_like_interaction_path(external)
    expect(response).to redirect_to(new_session_path(locale: I18n.locale))
    expect(PublicationLike.count).to eq(0)

    get new_session_path(return_to: publication_path(external, locale: nil))
    post session_path, params: { email_address: reader.email_address, password: "123" }
    expect(response).to redirect_to(publication_path(external, locale: nil))
  end
end
