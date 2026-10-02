require 'rails_helper'

RSpec.describe PresentationProfilePolicy, type: :policy do
  let(:record) { build(:presentation_profile) }

  it_behaves_like 'admin-only policy'

  it 'lets only admins choose the public default profile' do
    expect(described_class.new(build(:user, :admin), record).activate?).to be(true)
    expect(described_class.new(build(:user), record).activate?).to be(false)
    expect(described_class.new(nil, record).activate?).to be(false)
  end

  it 'does not allow deleting the active profile' do
    expect(described_class.new(build(:user, :admin), build(:presentation_profile, :active)).destroy?).to be(false)
  end

  describe '.scope' do
    it 'returns profiles only for an admin' do
      profile = create(:presentation_profile)

      expect(described_class::Scope.new(build(:user, :admin), PresentationProfile).resolve).to include(profile)
      expect(described_class::Scope.new(build(:user), PresentationProfile).resolve).to be_empty
    end
  end
end
