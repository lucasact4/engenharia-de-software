require "rails_helper"

RSpec.describe "Portal and handling policies" do
  let(:admin) { create(:user, :admin) }
  let(:author) { create(:user) }
  let(:reader) { create(:user) }
  let(:coordinator) { create(:user).tap { |user| grant_role(user, :coordination) } }
  let(:security) { create(:user).tap { |user| grant_role(user, :security) } }
  let(:inactive_admin) { create(:user, :admin, :inactive) }
  let(:alert) { create(:alert, :restricted, author: author) }
  let(:panic) { create(:alert, :panic, author: author) }

  describe AlertPolicy do
    it "opens the handling queue to admin, coordination and security only" do
      expect(AlertPolicy.new(admin, Alert).queue?).to be(true)
      expect(AlertPolicy.new(coordinator, Alert).queue?).to be(true)
      expect(AlertPolicy.new(security, Alert).queue?).to be(true)
      expect(AlertPolicy.new(reader, Alert).queue?).to be(false)
      expect(AlertPolicy.new(inactive_admin, Alert).queue?).to be(false)
      expect(AlertPolicy.new(nil, Alert).queue?).to be(false)
    end

    it "scopes the handling queue to what each team can handle" do
      assigned = create(:alert, :restricted, assigned_to: security)
      [ alert, panic ]

      expect(AlertPolicy::HandlingScope.new(coordinator, Alert).resolve).to contain_exactly(alert, assigned)
      expect(AlertPolicy::HandlingScope.new(security, Alert).resolve).to contain_exactly(panic, assigned)
      expect(AlertPolicy::HandlingScope.new(reader, Alert).resolve).to be_empty
      expect(AlertPolicy::HandlingScope.new(admin, Alert).resolve).to contain_exactly(alert, panic, assigned)
    end

    it "separates operational details, correction and photo removal" do
      expect(AlertPolicy.new(author, alert).show_operational_details?).to be(true)
      expect(AlertPolicy.new(coordinator, alert).show_operational_details?).to be(true)
      internal = create(:alert)
      expect(AlertPolicy.new(reader, internal).show?).to be(true)
      expect(AlertPolicy.new(reader, internal).show_operational_details?).to be(false)

      expect(AlertPolicy.new(admin, alert).correct_content?).to be(true)
      expect(AlertPolicy.new(coordinator, alert).correct_content?).to be(false)
      expect(AlertPolicy.new(author, alert).correct_content?).to be(false)

      expect(AlertPolicy.new(author, alert).remove_photo?).to be(true)
      expect(AlertPolicy.new(coordinator, alert).remove_photo?).to be(false)
    end
  end

  describe ProfilePolicy do
    it "only allows the active owner" do
      expect(ProfilePolicy.new(author, author).update?).to be(true)
      expect(ProfilePolicy.new(admin, author).update?).to be(false)
      expect(ProfilePolicy.new(create(:user, :inactive), author).update?).to be(false)
    end
  end

  describe PublicProfilePolicy do
    it "shows only active opt-in profiles" do
      expect(PublicProfilePolicy.new(nil, create(:user, :public_profile)).show?).to be(true)
      expect(PublicProfilePolicy.new(nil, create(:user)).show?).to be(false)
      expect(PublicProfilePolicy.new(nil, create(:user, :public_profile, :inactive)).show?).to be(false)
    end
  end

  describe PublicationPolicy::FeedScope do
    it "never includes drafts for admins and keeps internal content for active accounts" do
      draft = create(:publication)
      internal = create(:publication, :published, visibility: "internal")

      expect(PublicationPolicy::FeedScope.new(admin, Publication.all).resolve).to contain_exactly(internal)
      expect(PublicationPolicy::FeedScope.new(nil, Publication.all).resolve).to be_empty
      expect(PublicationPolicy::Scope.new(admin, Publication.all).resolve).to include(draft)
    end
  end

  describe "category and location policies" do
    it "are administrative and never allow destroy" do
      [ CategoryPolicy, LocationPolicy ].each do |policy_class|
        expect(policy_class.new(admin, Category).update?).to be(true)
        expect(policy_class.new(admin, Category).destroy?).to be(false)
        expect(policy_class.new(coordinator, Category).index?).to be(false)
      end
    end
  end
end
