require "rails_helper"

RSpec.describe PresentationProfile do
  let(:presentation) { Presentation.load }

  it "casts checkbox values and saves the selection" do
    profile = create(:presentation_profile, selections: { "gestao" => "1", "gestao.reunioes" => "0" })

    expect(profile.reload.selections).to eq("gestao" => true, "gestao.reunioes" => false)
  end

  it "keeps each profile's selection isolated" do
    first = create(:presentation_profile, selections: { "gestao.reunioes" => false })
    second = create(:presentation_profile, selections: { "gestao.reunioes" => true })

    first.update!(selections: { "gestao.reunioes" => true, "arquitetura" => false })

    expect(second.reload.selections).to eq("gestao.reunioes" => true)
    expect(first.reload.selection(presentation).slide_visible?(presentation.slide("arquitetura"))).to be(false)
    expect(second.selection(presentation).slide_visible?(presentation.slide("arquitetura"))).to be(true)
  end

  it "rejects keys outside the catalog" do
    profile = build(:presentation_profile, selections: { "gestao" => true, "slides/_capa" => true })

    expect(profile).not_to be_valid
    expect(profile.errors[:selections].join).to include("slides/_capa")
  end

  it "rejects values that are not booleans" do
    profile = build(:presentation_profile, selections: { "gestao" => "talvez" })

    expect(profile).not_to be_valid
    expect(profile.errors.of_kind?(:selections, :not_boolean)).to be(true)
  end

  it "does not allow hiding the cover or the closing slide" do
    Presentation::REQUIRED_SLIDES.each do |id|
      profile = build(:presentation_profile, selections: { id => "0" })

      expect(profile).not_to be_valid
      expect(profile.errors.of_kind?(:selections, :required_slides)).to be(true)
    end
  end

  it "requires a delivery from entrega.yml" do
    expect(build(:presentation_profile, delivery: "terceira")).not_to be_valid
    expect(build(:presentation_profile, delivery: "primeira")).to be_valid
  end

  it "keeps a single active profile" do
    first = create(:presentation_profile, :active)
    second = create(:presentation_profile)

    second.activate!

    expect(first.reload).not_to be_active
    expect(second.reload).to be_active
    expect(described_class.where(active: true).count).to eq(1)
  end

  it "still activates a profile saved before a catalog key was removed" do
    profile = create(:presentation_profile)
    profile.update_column(:selections, { "slide-removido" => true })

    expect { profile.reload.activate! }.not_to raise_error
  end

  describe ".for_presentation" do
    it "returns the requested profile, then the active one, and never creates records" do
      active = create(:presentation_profile, :active)
      other = create(:presentation_profile)

      expect { described_class.for_presentation }.not_to change(described_class, :count)
      expect(described_class.for_presentation).to eq(active)
      expect(described_class.for_presentation(other.id.to_s)).to eq(other)
      expect(described_class.for_presentation("1 OR 1=1")).to eq(active)
    end

    it "returns nil when no profile is active" do
      create(:presentation_profile)

      expect(described_class.for_presentation).to be_nil
    end
  end

  describe "initial profiles (db/seeds/presentation_profiles.rb)" do
    before { load Rails.root.join("db/seeds/presentation_profiles.rb") }

    it "creates the first and second delivery profiles with valid selections" do
      first = described_class.find_by!(delivery: "primeira")
      second = described_class.find_by!(delivery: "segunda")

      expect(second).to be_active
      expect(first.selection(presentation).visible_slides.map(&:id)).to include("requisitos", "arquitetura", "casos-de-uso", "gestao", "proximos-passos", "retrospectiva")
      expect(second.selection(presentation).visible_slides.map(&:id)).to include("conceito-visual", "funcionalidades", "retrospectiva", "modelo-conceitual", "gestao", "evolucao", "proximos-passos")
      expect(second.selection(presentation).over_limit?).to be(false)
    end

    it "does not overwrite profiles edited in the admin" do
      described_class.find_by!(delivery: "segunda").update!(selections: { "gestao" => false })

      load Rails.root.join("db/seeds/presentation_profiles.rb")

      expect(described_class.find_by!(delivery: "segunda").selections).to eq("gestao" => false)
      expect(described_class.count).to eq(2)
    end
  end
end
