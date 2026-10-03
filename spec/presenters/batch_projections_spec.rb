require "rails_helper"

RSpec.describe "Batch projections" do
  let(:viewer) { create(:user) }

  it "matches PublicationProjection#as_json for each record and drops records outside the scope" do
    visible = create(:publication, :published)
    draft = create(:publication)
    PublicationLike.create!(user: viewer, publication: visible)
    PublicationLike.create!(user: create(:user, :inactive), publication: visible)
    create(:comment, publication: visible)
    create(:comment, publication: visible, deleted_at: Time.current)

    batch = PublicationProjection.collection([ visible, draft ], viewer: viewer)

    expect(batch.map { |item| item[:id] }).to eq([ visible.id ])
    expect(batch.first).to eq(PublicationProjection.new(visible, viewer: viewer).as_json)
    expect(batch.first).to include(likes_count: 1, comments_count: 1, viewer_state: { liked: true, bookmarked: false, subscribed: false })
    expect(batch.first.keys).not_to include(:alert_id, :author_id)
  end

  it "keeps hidden comments without body, author or likes" do
    publication = create(:publication, :published)
    author = create(:user, :public_profile)
    visible = create(:comment, publication: publication, author: author)
    removed = create(:comment, publication: publication, author: author, body: "Texto removido")
    Comments::Moderate.call(actor: create(:user, :admin), comment: removed, reason: "x")
    CommentLike.create!(user: viewer, comment: visible)

    batch = CommentProjection.collection(publication.comments.chronological, viewer: viewer).index_by { |item| item[:id] }

    expect(batch[removed.id]).to include(state: "removed", body: nil, author: nil, likes_count: 0)
    expect(batch[removed.id].to_s).not_to include("Texto removido")
    expect(batch[visible.id]).to include(viewer_liked: true, likes_count: 1)
    expect(batch[visible.id].except(:viewer_liked, :own)).to eq(CommentProjection.new(visible, viewer: viewer).as_json)
  end

  it "drops comments of publications the viewer cannot read" do
    hidden = create(:comment, publication: create(:publication))

    expect(CommentProjection.collection([ hidden ], viewer: viewer)).to be_empty
  end
end
