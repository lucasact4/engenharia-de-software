require "rails_helper"

RSpec.describe "RF005/RF006 mural author privacy", type: :request do
  let(:author) { create(:user, :public_profile, display_name: "Autora Sigilosa", username: "autora_sigilo") }
  let(:reader) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:coordinator) { create(:user).tap { |user| grant_role(user, :coordination) } }
  let(:guard) { create(:user).tap { |user| grant_role(user, :security) } }

  def occurrence(author: self.author, anonymous: true, visibility: "public_external", **attributes)
    source = create(:alert, author: author, anonymous_public: anonymous,
                            requested_visibility: visibility == "internal" ? "internal" : "public_external",
                            visibility: visibility == "internal" ? "internal" : "restricted", **attributes)
    create(:publication, :published, kind: "occurrence", alert: source, visibility: visibility)
  end

  def card_ids
    Nokogiri::HTML(response.body).css("article.social-post h2[id]").map { |node| node["id"].delete_prefix("post_title_").to_i }
  end

  it "shows concealed posts to visitors without allowing name, username or combined filters to identify them" do
    hidden = occurrence(title: "Relato público sem identificação")
    public_post = occurrence(anonymous: false, title: "Relato com autoria visível")

    get publications_path
    expect(card_ids).to contain_exactly(hidden.id, public_post.id)
    get publication_path(hidden)
    expect(response.body).to include("Pessoa anônima")
    expect(response.body).not_to include(author.display_name, author.username, author.email_address)

    [ author.display_name, author.username, "autora", "SIGILO" ].each do |term|
      get publications_path(creator: term, q: "Relato", kind: "occurrence", category_id: hidden.alert.category_id)
      expect(card_ids).not_to include(hidden.id)
    end
    get publications_path(creator: author.display_name)
    expect(card_ids).to eq([ public_post.id ])
  end

  it "hides identity and creator matches from ordinary readers in pending internal and external posts" do
    hidden = occurrence
    pending = occurrence(visibility: "internal", title: "Relato em aprovação")
    pending.update!(review_status: "pending", reviewed_content_version: nil)
    sign_in(reader)

    [ hidden, pending ].each do |post|
      get publication_path(post)
      expect(response.body).to include("Pessoa anônima")
      expect(response.body).not_to include(author.display_name, author.username, author.email_address)
    end
    get publications_path(creator: author.display_name)
    expect(card_ids).to be_empty
  end

  it "preserves operational identity and search for the author, administrators and coordination" do
    hidden = occurrence
    [ author, admin, coordinator ].each do |viewer|
      sign_in(viewer)
      get publication_path(hidden)
      expect(response.body).to include(author.display_name)
      get publications_path(creator: author.display_name)
      expect(card_ids).to include(hidden.id)
    end
  end

  it "does not let security identify unassigned occurrences, and revokes identification after unassignment" do
    hidden = occurrence
    sign_in(guard)
    get publications_path(creator: author.display_name)
    expect(card_ids).to be_empty

    hidden.alert.update!(assigned_to: guard)
    get publications_path(creator: author.display_name)
    expect(card_ids).to eq([ hidden.id ])
    get publication_path(hidden)
    expect(response.body).to include(author.display_name)

    hidden.alert.update!(assigned_to: nil)
    get publications_path(creator: author.display_name)
    expect(card_ids).to be_empty
  end

  it "does not reveal private external profiles, non-displayed usernames, business names or editorial authors" do
    private_author = create(:user, display_name: "Nome Interno", username: "usuario_privado", business_name: "Empresa Reservada")
    private_post = occurrence(author: private_author, anonymous: false)
    internal_post = occurrence(author: private_author, anonymous: false, visibility: "internal")
    editorial = create(:publication, :published, author: private_author)

    get publications_path(creator: private_author.display_name)
    expect(card_ids).to be_empty
    sign_in(reader)
    get publications_path(creator: private_author.display_name)
    expect(card_ids).to eq([ internal_post.id ])
    [ private_author.username, private_author.business_name ].each do |term|
      get publications_path(creator: term)
      expect(card_ids).not_to include(private_post.id, internal_post.id, editorial.id)
    end
  end

  it "finds a username used as the visible display-name fallback" do
    fallback = create(:user, display_name: nil, username: "nome_de_fallback")
    post = occurrence(author: fallback, anonymous: false, visibility: "internal")
    sign_in(reader)
    get publication_path(post)
    expect(response.body).to include("nome_de_fallback")
    get publications_path(creator: "nome_de_fallback")
    expect(card_ids).to eq([ post.id ])
  end

  it "does not identify a deactivated author whose displayed identity became neutral" do
    post = occurrence(anonymous: false)
    author.update!(deleted_at: Time.current)
    get publications_path(creator: author.display_name)
    expect(card_ids).not_to include(post.id)
  end

  it "excludes concealed matches before pagination instead of leaking them through result pages" do
    11.times { |index| occurrence(title: "Relato protegido #{index}") }
    visible = occurrence(anonymous: false, title: "Relato permitido")
    get publications_path(creator: author.display_name)
    expect(card_ids).to eq([ visible.id ])
    get publications_path(creator: author.display_name, page: 2)
    expect(card_ids).to be_empty
  end

  it "keeps keyword search usable without interpreting author data as keywords" do
    post = occurrence(title: "Buraco confidencial na calçada")
    get publications_path(q: "Buraco confidencial")
    expect(card_ids).to eq([ post.id ])
    get publications_path(q: author.username)
    expect(card_ids).to be_empty
  end
end
