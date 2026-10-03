require "rails_helper"

RSpec.describe DashboardPolicy, type: :policy do
  let(:record) { :dashboard }

  it "allows an active admin" do
    policy = described_class.new(build(:user, :admin), record)

    expect(policy.menu?).to be(true)
    expect(policy.index?).to be(true)
  end

  it "denies regular, deactivated and anonymous users" do
    [ build(:user), build(:user, :admin, :inactive), nil ].each do |user|
      policy = described_class.new(user, record)

      expect(policy.menu?).to be(false)
      expect(policy.index?).to be(false)
    end
  end
end
