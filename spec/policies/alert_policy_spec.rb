require "rails_helper"

RSpec.describe AlertPolicy do
  let(:author) { create(:user) }
  let(:other) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:coordinator) { create(:user).tap { |user| grant_role(user, :coordination) } }
  let(:guard) { create(:user).tap { |user| grant_role(user, :security) } }

  let!(:internal) { create(:alert, author: author) }
  let!(:restricted) { create(:alert, :restricted, author: author) }
  let!(:public_request) { create(:alert, :public_request, author: author) }
  let!(:panic) { create(:alert, :panic, author: author) }
  let!(:security_category) { create(:alert, :restricted, category: create(:category, code: "security", name: "Segurança")) }

  def visible(user)
    described_class::Scope.new(user, Alert.all).resolve
  end

  it "shows nothing to anonymous or deactivated accounts" do
    expect(visible(nil)).to be_empty
    expect(visible(create(:user, :inactive))).to be_empty
    expect(described_class.new(nil, internal).show?).to be(false)
  end

  it "shows a regular user their own alerts plus internal occurrences" do
    expect(visible(author)).to contain_exactly(internal, restricted, public_request, panic)
    expect(visible(other)).to contain_exactly(internal)
  end

  it "does not widen access for professor, student, staff, visitor or resident roles" do
    %i[professor student staff visitor resident].each { |code| grant_role(other, code) }

    expect(visible(other)).to contain_exactly(internal)
    expect(described_class.new(other, internal).handle?).to be(false)
  end

  it "gives coordination all occurrences but no panic" do
    expect(visible(coordinator)).to contain_exactly(internal, restricted, public_request, security_category)
    expect(described_class.new(coordinator, restricted).handle?).to be(true)
    expect(described_class.new(coordinator, panic).show?).to be(false)
  end

  it "gives security panics and directly assigned occurrences only" do
    expect(visible(guard)).to contain_exactly(internal, panic)
    expect(described_class.new(guard, security_category).show?).to be(false)

    security_category.update!(assigned_to: guard)
    expect(visible(guard)).to include(security_category)
  end

  it "gives active admins everything" do
    expect(visible(admin)).to contain_exactly(internal, restricted, public_request, panic, security_category)
  end

  it "uses the same rule for show and index" do
    Alert.find_each do |alert|
      [ author, other, coordinator, guard, admin ].each do |user|
        expect(described_class.new(user, alert).show?).to eq(visible(user).include?(alert))
      end
    end
  end

  it "keeps original photos restricted to author and handlers" do
    expect(described_class.new(other, internal).show_photos?).to be(false)
    expect(described_class.new(author, internal).show_photos?).to be(true)
    expect(described_class.new(coordinator, internal).show_photos?).to be(true)
  end

  it "revokes access when a role is deactivated" do
    coordinator.roles.find_by!(code: "coordination").update!(active: false)

    expect(visible(coordinator)).to contain_exactly(internal)
  end
end
