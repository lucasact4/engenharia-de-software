require "rails_helper"

RSpec.describe "RF005 concealed-author occurrences" do
  let(:author) { build_stubbed(:user, :public_profile, verified_at: Time.current) }
  let(:alert) { Alert.new(kind: "occurrence", author: author, anonymous_public: true) }

  describe AlertPolicy do
    it "only permits an active account to submit an occurrence" do
      pending_user = build_stubbed(:user, registration_status: "pending")

      expect(described_class.new(nil, Alert).create_occurrence?).to be(false)
      expect(described_class.new(pending_user, Alert).create_occurrence?).to be(false)
      expect(described_class.new(author, Alert).create_occurrence?).to be(true)
    end
  end

  describe TurnstileVerifier do
    it "rejects a missing challenge response without contacting the provider" do
      allow(described_class).to receive(:configured?).and_return(true)
      expect(Net::HTTP).not_to receive(:new)

      expect(described_class.verify(nil, expected_hostname: "sgu.example.test")).to be(false)
    end
  end

  describe PublicationProjection do
    it "keeps the public report visible while concealing the verified author's public identity" do
      allow(author.avatar).to receive(:attached?).and_return(true)
      alert.title = "Luz apagada no corredor"
      publication = Publication.new(kind: "occurrence", visibility: "public_external", alert: alert, author: author)

      payload = described_class.new(publication).payload(likes_count: 0, comments_count: 0, viewer_state: nil)

      expect(payload[:title]).to eq("Luz apagada no corredor")
      expect(payload[:author]).to eq(
        display_name: "Pessoa anônima", username: nil, public_profile: false,
        id: nil, avatar_id: nil, verified: false
      )
    end
  end

  describe AlertDetailPresenter do
    it "identifies the author as the current user in the authorized alert detail" do
      detail = described_class.new(alert, viewer: author)

      expect(detail).to be_operational
      expect(detail.author_label).to eq("Você")
    end
  end
end
