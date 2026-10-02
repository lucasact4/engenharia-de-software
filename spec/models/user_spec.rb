require 'rails_helper'

RSpec.describe User, type: :model do
  it "normalizes email_address before validation" do
    user = create(:user, email_address: "  USER@Example.COM  ")

    expect(user.email_address).to eq("user@example.com")
  end

  it "removes sessions when the user is destroyed" do
    user = create(:user)
    session = user.sessions.create!(ip_address: "127.0.0.1", user_agent: "RSpec")

    expect { user.destroy }.to change(Session, :count).by(-1)
    expect(Session.exists?(session.id)).to be(false)
  end

  describe "profile fields" do
    it "keeps legacy accounts valid without profile data and private by default" do
      user = create(:user)

      expect(user).to be_valid
      expect(user.public_profile).to be(false)
      expect([ user.display_name, user.username, user.bio ]).to all(be_nil)
    end

    it "normalizes username to lowercase and blank values to nil" do
      user = create(:user, username: "  Pessoa_01 ", display_name: "  Nome   Fictício ", bio: "   ")

      expect(user.username).to eq("pessoa_01")
      expect(user.display_name).to eq("Nome Fictício")
      expect(user.bio).to be_nil
      expect(create(:user, username: "").username).to be_nil
    end

    it "rejects usernames with spaces, symbols or invalid length" do
      [ "com espaco", "ab", "a" * 31, "ponto.final", "hífen" ].each do |username|
        expect(build(:user, username: username)).not_to be_valid, username
      end
    end

    it "enforces username uniqueness case-insensitively" do
      create(:user, username: "pessoa")

      expect(build(:user, username: "PESSOA")).not_to be_valid
    end

    it "does not derive profile data from the e-mail" do
      user = create(:user, email_address: "nome.sobrenome@example.com")

      expect(user.username).to be_nil
      expect(user.display_name).to be_nil
    end
  end

  describe "#role?" do
    let(:user) { create(:user) }

    it "supports multiple roles for the same person" do
      grant_role(user, :student)
      grant_role(user, :resident)

      expect(user.role?(:student)).to be(true)
      expect(user.role?(:resident)).to be(true)
      expect(user.role?(:coordination)).to be(false)
    end

    it "ignores inactive roles, unknown codes and deactivated accounts" do
      grant_role(user, :coordination, active: false)
      grant_role(user, :superpoder)

      expect(user.role?(:coordination)).to be(false)
      expect(user.role?(:superpoder)).to be(false)

      grant_role(user, :security)
      user.update!(deleted_at: Time.current)
      expect(user.role?(:security)).to be(false)
    end

    it "does not turn coordination or professor into administrators" do
      grant_role(user, :coordination)
      grant_role(user, :professor)

      expect(user.admin?).to be(false)
    end
  end

  it "does not destroy authored history when deletion is attempted" do
    alert = create(:alert)

    expect { alert.author.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
    expect(Alert.exists?(alert.id)).to be(true)
  end
end
