require "rails_helper"

RSpec.describe "Profile updates and own-link cleanup" do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }

  describe Users::UpdateProfile do
    it "updates own profile fields only and audits the changed fields" do
      described_class.call(actor: user, user: user, attributes: { display_name: "Nome", username: "MeuNome", public_profile: true, admin: true })

      expect(user.reload).to have_attributes(display_name: "Nome", username: "meunome", public_profile: true, admin: false)
      expect(AuditEvent.where(subject: user, action: "user.profile_updated").pick(:metadata)["fields"]).to contain_exactly("display_name", "username", "public_profile")
    end

    it "does not let other regular users edit someone's profile" do
      expect { described_class.call(actor: create(:user), user: user, attributes: { bio: "invasão" }) }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "lets admins edit and unpublish, but not opt someone in" do
      expect { described_class.call(actor: admin, user: user, attributes: { public_profile: true }) }.to raise_error(ActiveRecord::RecordInvalid)

      user.update!(public_profile: true)
      described_class.call(actor: admin, user: user, attributes: { public_profile: false, bio: "Revisado" }, reason: "Moderação")
      expect(user.reload).to have_attributes(public_profile: false, bio: "Revisado")
    end

    it "rejects deactivated actors" do
      user.update!(deleted_at: Time.current)
      expect { described_class.call(actor: user, user: user, attributes: { bio: "x" }) }.to raise_error(Pundit::NotAuthorizedError)
    end
  end

  describe "Social::Interactions.prune_inaccessible" do
    it "removes only the actor's links whose target is no longer accessible and returns how many" do
      visible = create(:publication, :published)
      withdrawn = create(:publication, :published)
      other = create(:user)
      [ visible, withdrawn ].each { |publication| PublicationBookmark.create!(user: user, publication: publication) }
      PublicationBookmark.create!(user: other, publication: withdrawn)
      Publications::Withdraw.call(actor: admin, publication: withdrawn, reason: "x")

      expect(Social::Interactions.prune_inaccessible(actor: user, kind: :bookmark)).to eq(1)
      expect(user.publication_bookmarks.pluck(:publication_id)).to eq([ visible.id ])
      expect(other.publication_bookmarks.count).to eq(1)
    end

    it "prunes alert subscriptions after the alert becomes restricted" do
      alert = create(:alert)
      Social::Interactions.subscribe_alert(actor: user, alert: alert)
      alert.update_columns(requested_visibility: "restricted", visibility: "restricted")

      expect(SubscribedAlertsQuery.new(user).unavailable_count).to eq(1)
      expect(Social::Interactions.prune_inaccessible(actor: user, kind: :alert_subscription)).to eq(1)
    end

    it "requires an active actor" do
      expect { Social::Interactions.prune_inaccessible(actor: create(:user, :inactive), kind: :bookmark) }.to raise_error(Pundit::NotAuthorizedError)
    end
  end
end
