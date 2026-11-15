require "rails_helper"

RSpec.describe Alert, "RF007 — fotos na postagem", type: :model do
  it "permite postagem sem foto e aceita arquivos PNG e JPEG válidos" do
    alert = build(:alert)
    alert.photos.attach(photo, photo(bytes: SguSupport::JPEG_BYTES, filename: "foto.jpg", content_type: "image/jpeg"))

    expect(alert).to be_valid
    expect(build(:alert)).to be_valid
  end

  it "rejeita conteúdo que não é PNG ou JPEG mesmo com extensão e MIME falsificados" do
    alert = build(:alert)
    alert.photos.attach(photo(bytes: "isto é texto, não imagem", filename: "falsa.png", content_type: "image/png"))

    expect(alert).not_to be_valid
    expect(alert.errors.details[:photos]).to include(error: :content_type)
  end

  it "limita a postagem a cinco fotos de até 5 MB cada" do
    too_many = build(:alert)
    too_many.photos.attach(Array.new(6) { photo })
    expect(too_many).not_to be_valid

    large = build(:alert)
    large.photos.attach(photo(bytes: SguSupport::PNG_BYTES + ("0" * Alert::MAX_PHOTO_BYTES)))
    expect(large).not_to be_valid
    expect(large.errors.details[:photos]).to include(a_hash_including(error: :too_large))
  end

  it "impede reutilizar em outra postagem um arquivo já anexado" do
    other = create(:alert)
    other.photos.attach(photo)
    alert = build(:alert)
    alert.photos.attach(other.photos.first.blob)

    expect(alert).not_to be_valid
    expect(alert.errors.details[:photos]).to include(error: :reused_blob)
  end
end
