require "rails_helper"

RSpec.describe "Profiles, follows and private lists", type: :request do
  let(:user) { create(:user, display_name: "Pessoa Leitora") }
  let(:public_person) { create(:user, :public_profile, display_name: "Bia Pública", bio: "Estudante de agronomia") }
  let(:private_person) { create(:user, display_name: "Carlos Privado") }

  describe "own profile" do
    before { sign_in(user) }

    it "edits only profile fields and opts in explicitly" do
      patch profile_path, params: { user: { display_name: "Novo Nome", username: "Novo_Nome", bio: "Olá", public_profile: "1",
                                            admin: "1", email_address: "hack@example.com", deleted_at: Time.current, role_ids: [ 1 ] } }

      expect(user.reload).to have_attributes(display_name: "Novo Nome", username: "novo_nome", bio: "Olá", public_profile: true,
                                             admin: false, deleted_at: nil)
      expect(user.email_address).not_to eq("hack@example.com")
      expect(AuditEvent.where(subject: user, action: "user.profile_updated")).to exist
    end

    it "validates username format and uniqueness" do
      create(:user, username: "ocupado")

      patch profile_path, params: { user: { username: "ocupado" } }
      expect(response).to have_http_status(:unprocessable_entity)

      patch profile_path, params: { user: { username: "com espaço!" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "starts private" do
      get profile_path
      expect(response.body).to include("Privado. Seu nome continua aparecendo nas publicações internas.")
      get person_path(user)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "public profiles" do
    it "shows only opt-in active profiles without private data" do
      alert = create(:alert, author: public_person, title: "Alerta pessoal da Bia")
      PublicationBookmark.create!(user: public_person, publication: create(:publication, :published, title: "Salvo privado da Bia"))
      grant_role(public_person, :security)

      get person_path(public_person)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Bia Pública", "Estudante de agronomia")
      expect(response.body).not_to include(public_person.email_address)
      expect(response.body).not_to include(alert.title)
      expect(response.body).not_to include("Salvo privado da Bia")
      expect(response.body).not_to include("Security")

      get person_path(private_person)
      expect(response).to have_http_status(:not_found)

      public_person.update!(deleted_at: Time.current)
      get person_path(public_person)
      expect(response).to have_http_status(:not_found)
    end

    it "lists only public profiles in the directory" do
      public_person
      private_person
      get people_path

      expect(response.body).to include("Bia Pública")
      expect(response.body).not_to include("Carlos Privado")
    end
  end

  describe "follows" do
    before { sign_in(user) }

    it "follows and unfollows idempotently, never self or private profiles" do
      2.times { post person_follow_path(public_person) }
      expect(UserFollow.where(follower: user, followed: public_person).count).to eq(1)

      post person_follow_path(private_person)
      expect(response).to have_http_status(:not_found)

      user.update!(public_profile: true)
      post person_follow_path(user)
      expect(response).to have_http_status(:forbidden)
      expect(UserFollow.where(followed: user)).to be_empty

      delete person_follow_path(public_person)
      expect(UserFollow.count).to eq(0)
    end

    it "keeps links after opt-out, hiding them until the profile is public again" do
      post person_follow_path(public_person)
      public_person.update!(public_profile: false)

      get follow_ups_path
      expect(response.body).not_to include("Bia Pública")
      expect(UserFollow.where(follower: user, followed: public_person)).to exist

      public_person.update!(public_profile: true)
      get follow_ups_path
      expect(response.body).to include("Bia Pública")
    end

    it "counts followers but only lists public, active ones" do
      user.update!(public_profile: true)
      post person_follow_path(public_person)
      hidden_follower = create(:user, display_name: "Seguidor Privado")
      UserFollow.create!(follower: hidden_follower, followed: public_person)

      get followers_person_path(public_person)
      expect(response.body).to include("2 seguidores")
      expect(response.body).to include("Pessoa Leitora")
      expect(response.body).not_to include("Seguidor Privado")
    end
  end

  describe "saved items and follow-ups" do
    let(:admin) { create(:user, :admin) }
    let!(:publication) { create(:publication, :published, title: "Publicação salva") }

    before { sign_in(user) }

    it "keeps saved items private and prunes only the viewer's inaccessible links" do
      post publication_bookmark_interaction_path(publication)
      other = create(:user)
      PublicationBookmark.create!(user: other, publication: publication)

      get saved_publications_path
      expect(response.body).to include("Publicação salva")

      Publications::Withdraw.call(actor: admin, publication: publication, reason: "Retirada")
      get saved_publications_path
      expect(response.body).not_to include("Publicação salva")

      delete prune_follow_ups_path(tipo: "salvos")
      expect(PublicationBookmark.where(user: user)).to be_empty
      expect(PublicationBookmark.where(user: other)).to exist
    end

    it "rejects unknown prune kinds" do
      delete prune_follow_ups_path(tipo: "usuarios")
      expect(response).to have_http_status(:not_found)
    end
  end

  it "requires login for private lists and profile editing" do
    [ saved_publications_path, follow_ups_path, profile_path, edit_profile_path, content_reports_path ].each do |path|
      get path
      expect(response).to redirect_to(new_session_path(locale: I18n.locale)), path
    end
  end
end
