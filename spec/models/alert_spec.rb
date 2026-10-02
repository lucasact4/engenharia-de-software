require "rails_helper"

RSpec.describe Alert, type: :model do
  describe "occurrence" do
    it "requires title, description, category and location" do
      alert = build(:alert, title: nil, description: nil, category: nil, location_source: "unavailable",
                            latitude: nil, longitude: nil)

      expect(alert).not_to be_valid
      expect(alert.errors.attribute_names).to include(:title, :description, :category, :location_source)
    end

    it "applies the documented text limits" do
      expect(build(:alert, title: "abc")).not_to be_valid
      expect(build(:alert, title: "a" * 161)).not_to be_valid
      expect(build(:alert, description: "curta")).not_to be_valid
      expect(build(:alert, description: "a" * 5001)).not_to be_valid
      expect(build(:alert, title: "a" * 160, description: "a" * 5000)).to be_valid
    end

    it "accepts GPS with a valid coordinate pair" do
      alert = build(:alert, location_source: "gps", latitude: -8.01, longitude: -34.95, location_accuracy_meters: 12.5)

      expect(alert).to be_valid
    end

    it "rejects missing or out-of-range coordinates" do
      expect(build(:alert, latitude: nil)).not_to be_valid
      expect(build(:alert, latitude: 91)).not_to be_valid
      expect(build(:alert, longitude: -181)).not_to be_valid
      expect(build(:alert, location_accuracy_meters: -1)).not_to be_valid
    end

    it "accepts manual selection of an active location without coordinates" do
      location = create(:location)

      expect(build(:alert, location_source: "manual", location: location, latitude: nil, longitude: nil)).to be_valid
      expect(build(:alert, location_source: "manual", location: location)).not_to be_valid
      expect(build(:alert, location_source: "manual", location: nil, latitude: nil, longitude: nil)).not_to be_valid
    end

    it "requires an explanation for the category Outro" do
      other = create(:category, :other)

      expect(build(:alert, category: other)).not_to be_valid
      expect(build(:alert, category: other, category_other_description: "Bicicletário danificado")).to be_valid
    end

    it "keeps inactive catalog entries in history but rejects new associations" do
      category = create(:category)
      location = create(:location)
      alert = create(:alert, category: category, location_source: "manual", location: location, latitude: nil, longitude: nil)
      category.update!(active: false)
      location.update!(active: false)

      expect(alert.reload).to be_valid
      expect(build(:alert, category: category)).not_to be_valid
      expect(build(:alert, location_source: "manual", location: location, latitude: nil, longitude: nil)).not_to be_valid
    end

    it "never makes the operational record public" do
      expect(build(:alert, requested_visibility: "public_external", visibility: "internal")).not_to be_valid
      expect(build(:alert, :public_request)).to be_valid
      expect { build(:alert, visibility: "public_external") }.not_to raise_error
      expect(build(:alert, visibility: "public_external")).not_to be_valid
    end

    it "keeps reported severity independent from the assessed severity and priority" do
      alert = create(:alert, reported_severity: "high")

      expect(alert.assessed_severity).to be_nil
      expect(alert.priority).to be_nil
    end
  end

  describe "panic" do
    it "accepts the minimal request without text, photo, category or GPS" do
      alert = build(:alert, :panic, location_unavailable_reason: "permission_denied")

      expect(alert).to be_valid
    end

    it "is always restricted and requires a client key" do
      expect(build(:alert, :panic, requested_visibility: "internal", visibility: "internal")).not_to be_valid
      expect(build(:alert, :panic, client_request_id: nil)).not_to be_valid
    end

    it "does not need the occurrence minimum lengths" do
      expect(build(:alert, :panic, description: "Socorro")).to be_valid
    end
  end

  describe "closure" do
    it "requires reason and notes when closing as invalid" do
      alert = build(:alert, status: "closed", closed_at: Time.current, closure_reason: "invalid")

      expect(alert).not_to be_valid
      expect(alert.errors).to include(:closure_notes)
    end

    it "does not require a fictitious resolved_at for invalid closure" do
      alert = build(:alert, status: "closed", closed_at: Time.current, closure_reason: "invalid", closure_notes: "Teste")

      expect(alert).to be_valid
      expect(alert.resolved_at).to be_nil
    end

    it "rejects closure fields while open and duplicate cycles" do
      expect(build(:alert, closure_reason: "other")).not_to be_valid

      first = create(:alert)
      second = create(:alert, status: "closed", closed_at: Time.current, closure_reason: "duplicate", duplicate_of: first)
      first.assign_attributes(status: "closed", closed_at: Time.current, closure_reason: "duplicate", duplicate_of: second)

      expect(first).not_to be_valid
      expect(first.errors.details[:duplicate_of]).to include(error: :cycle)
    end
  end

  describe "photos" do
    it "is optional and accepts real PNG and JPEG files" do
      alert = build(:alert)
      alert.photos.attach(photo, photo(bytes: SguSupport::JPEG_BYTES, filename: "foto.jpg", content_type: "image/jpeg"))

      expect(alert).to be_valid
      expect(build(:alert)).to be_valid
    end

    it "rejects files whose content is not PNG/JPEG even with a PNG name and MIME" do
      alert = build(:alert)
      alert.photos.attach(photo(bytes: "isto é texto, não imagem", filename: "falsa.png", content_type: "image/png"))

      expect(alert).not_to be_valid
      expect(alert.errors.details[:photos]).to include(error: :content_type)
    end

    it "rejects more than five photos and files above 5 MiB" do
      too_many = build(:alert)
      too_many.photos.attach(Array.new(6) { photo })
      expect(too_many).not_to be_valid

      large = build(:alert)
      large.photos.attach(photo(bytes: SguSupport::PNG_BYTES + ("0" * Alert::MAX_PHOTO_BYTES)))
      expect(large).not_to be_valid
      expect(large.errors.details[:photos]).to include(a_hash_including(error: :too_large))
    end

    it "does not reuse a blob uploaded for another record" do
      other = create(:alert)
      other.photos.attach(photo)
      alert = build(:alert)
      alert.photos.attach(other.photos.first.blob)

      expect(alert).not_to be_valid
      expect(alert.errors.details[:photos]).to include(error: :reused_blob)
    end
  end

  it "generates an opaque unique protocol on the server" do
    alert = create(:alert, protocol: nil)

    expect(alert.protocol).to match(/\ASGU-[A-Z2-9]{5}-[A-Z2-9]{5}\z/)
  end
end
