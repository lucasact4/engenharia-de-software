require "rails_helper"

RSpec.describe PublicationPolicy do
  let(:user) { create(:user) }
  let!(:external) { create(:publication, :published) }
  let!(:internal) { create(:publication, :published, visibility: "internal") }
  let!(:draft) { create(:publication) }
  let!(:approved) { create(:publication, :approved) }
  let!(:expired) { create(:publication, :published, expires_at: 1.minute.ago, published_at: 1.hour.ago) }

  def visible(viewer)
    described_class::Scope.new(viewer, Publication.all).resolve
  end

  it "shows anonymous visitors only approved, published, current external content" do
    expect(visible(nil)).to contain_exactly(external)
  end

  it "adds internal content for active accounts and treats deactivated ones as anonymous" do
    expect(visible(user)).to contain_exactly(external, internal)
    expect(visible(create(:user, :inactive))).to contain_exactly(external)
  end

  it "shows everything to active admins only" do
    expect(visible(create(:user, :admin))).to include(draft, approved, expired)
    expect(visible(create(:user, :admin, :inactive))).to contain_exactly(external)
  end

  it "requires an active account and current access to interact" do
    expect(described_class.new(nil, external).interact?).to be(false)
    expect(described_class.new(user, draft).interact?).to be(false)
    expect(described_class.new(user, external).interact?).to be(true)
    external.update!(comments_enabled: false)
    expect(described_class.new(user, external).comment?).to be(false)
  end
end
