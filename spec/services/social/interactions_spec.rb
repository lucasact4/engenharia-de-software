require "rails_helper"

RSpec.describe Social::Interactions do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:publication) { create(:publication, :published) }

  it "adds and removes idempotently without toggling" do
    2.times { described_class.add_to_publication(actor: user, publication: publication, kind: :like) }
    expect(PublicationLike.where(user: user).count).to eq(1)

    2.times { described_class.remove_from_publication(actor: user, publication: publication, kind: :like) }
    expect(PublicationLike.where(user: user).count).to eq(0)
  end

  it "handles a concurrent duplicate insert through the unique index" do
    PublicationBookmark.create!(user: user, publication: publication)
    allow(PublicationBookmark).to receive(:find_or_create_by!).and_raise(ActiveRecord::RecordNotUnique)

    expect(described_class.add_to_publication(actor: user, publication: publication, kind: :bookmark)).to be_persisted
  end

  it "requires an active account and current access" do
    expect { described_class.add_to_publication(actor: nil, publication: publication, kind: :like) }.to raise_error(Pundit::NotAuthorizedError)
    expect { described_class.add_to_publication(actor: create(:user, :inactive), publication: publication, kind: :like) }
      .to raise_error(Pundit::NotAuthorizedError)
    expect { described_class.add_to_publication(actor: user, publication: create(:publication), kind: :like) }
      .to raise_error(Pundit::NotAuthorizedError)
  end

  it "keeps bookmarks private and revalidates access after revocation" do
    described_class.add_to_publication(actor: user, publication: publication, kind: :bookmark)
    described_class.add_to_publication(actor: user, publication: publication, kind: :subscription)
    expect(BookmarkedPublicationsQuery.new(user).call).to contain_exactly(publication)
    expect(BookmarkedPublicationsQuery.new(create(:user)).call).to be_empty
    expect(PublicationProjection.new(publication, viewer: create(:user)).as_json[:viewer_state]).to include(bookmarked: false)

    Publications::Withdraw.call(actor: admin, publication: publication, reason: "Revogação")

    expect(BookmarkedPublicationsQuery.new(user).call).to be_empty
    expect { PublicationProjection.new(publication, viewer: user).as_json }.to raise_error(Pundit::NotAuthorizedError)
    expect { described_class.add_to_publication(actor: user, publication: publication, kind: :like) }.to raise_error(Pundit::NotAuthorizedError)
    expect { described_class.remove_from_publication(actor: user, publication: publication, kind: :bookmark) }.not_to raise_error
  end

  it "counts only likes from active accounts" do
    described_class.add_to_publication(actor: user, publication: publication, kind: :like)
    other = create(:user)
    described_class.add_to_publication(actor: other, publication: publication, kind: :like)
    other.update!(deleted_at: Time.current)

    expect(PublicationProjection.new(publication).as_json[:likes_count]).to eq(1)
  end

  it "likes visible comments only" do
    comment = create(:comment, publication: publication)
    described_class.like_comment(actor: user, comment: comment)
    expect(comment.comment_likes.count).to eq(1)

    removed = create(:comment, publication: publication, removed_at: Time.current, removed_by: admin, removal_reason: "x")
    expect { described_class.like_comment(actor: user, comment: removed) }.to raise_error(Pundit::NotAuthorizedError)
  end

  it "subscribes only to accessible occurrences and filters after revocation" do
    alert = create(:alert)
    described_class.subscribe_alert(actor: user, alert: alert)
    expect(SubscribedAlertsQuery.new(user).call).to contain_exactly(alert)

    Alerts::Restrict.call(actor: admin, alert: alert, reason: "Revisão")
    expect(SubscribedAlertsQuery.new(user).call).to be_empty
    expect { described_class.subscribe_alert(actor: user, alert: create(:alert, :restricted)) }.to raise_error(Pundit::NotAuthorizedError)
  end

  describe "follows" do
    let(:public_person) { create(:user, :public_profile) }

    it "requires opt-in, an active account and forbids self follow" do
      expect { described_class.follow(actor: user, user: create(:user)) }.to raise_error(Pundit::NotAuthorizedError)
      expect { described_class.follow(actor: user, user: create(:user, :public_profile, :inactive)) }.to raise_error(Pundit::NotAuthorizedError)
      expect { described_class.follow(actor: public_person, user: public_person) }.to raise_error(Pundit::NotAuthorizedError)

      2.times { described_class.follow(actor: user, user: public_person) }
      expect(UserFollow.count).to eq(1)
    end

    it "hides existing follows after opt-out and ignores inactive followers in counts" do
      described_class.follow(actor: user, user: public_person)
      follower = create(:user, :public_profile)
      described_class.follow(actor: follower, user: public_person)
      query = PublicFollowersQuery.new(public_person)
      expect(query.call).to contain_exactly(follower)
      expect(query.count).to eq(2)

      follower.update!(deleted_at: Time.current)
      expect(PublicFollowersQuery.new(public_person).count).to eq(1)

      public_person.update!(public_profile: false)
      expect(PublicFollowersQuery.new(public_person).call).to be_empty
      expect(PublicFollowersQuery.new(public_person).count).to eq(0)
      expect { described_class.follow(actor: create(:user), user: public_person) }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "does not grant access to alerts or publications" do
      restricted = create(:alert, :restricted, author: public_person)
      described_class.follow(actor: user, user: public_person)

      expect(AlertPolicy::Scope.new(user, Alert.all).resolve).not_to include(restricted)
    end
  end
end

RSpec.describe Social::Interactions, ".upsert race" do
  it "treats a uniqueness validation failure from a concurrent insert as success" do
    user = create(:user)
    publication = create(:publication, :published)
    existing = PublicationLike.create!(user: user, publication: publication)
    invalid = PublicationLike.new(user: user, publication: publication).tap(&:valid?)
    allow(PublicationLike).to receive(:find_or_create_by!).and_raise(ActiveRecord::RecordInvalid.new(invalid))

    expect(described_class.add_to_publication(actor: user, publication: publication, kind: :like)).to eq(existing)
  end
end
