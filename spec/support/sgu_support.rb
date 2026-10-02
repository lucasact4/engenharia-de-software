# Auxiliares dos testes do domínio SGU (ocorrências, publicações e base social).
module SguSupport
  def self.png_chunk(type, data)
    [ data.bytesize ].pack("N") + type + data + [ Zlib.crc32(type + data) ].pack("N")
  end

  PNG_BYTES = ("\x89PNG\r\n\x1A\n".b +
               png_chunk("IHDR", [ 1, 1, 8, 2, 0, 0, 0 ].pack("NNCCCCC")) +
               png_chunk("IDAT", Zlib::Deflate.deflate("\x00\xFF\x00\x00".b)) +
               png_chunk("IEND", "")).b.freeze
  JPEG_BYTES = Base64.decode64(
    "/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////" \
    "////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA="
  ).freeze

  # Concede um papel diretamente (configuração de teste; o fluxo real usa Roles::Grant).
  def grant_role(user, code, active: true)
    role = Role.find_or_create_by!(code: code.to_s) { |r| r.name = code.to_s.humanize; r.active = active }
    user.user_roles.create!(role: role)
    role
  end

  def photo(bytes: PNG_BYTES, filename: "foto.png", content_type: "image/png")
    { io: StringIO.new(bytes.dup), filename: filename, content_type: content_type }
  end

  def uploaded_photo(bytes: PNG_BYTES, filename: "foto.png", content_type: "image/png")
    file = Tempfile.new([ "foto", File.extname(filename) ])
    file.binmode
    file.write(bytes)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, content_type, true, original_filename: filename)
  end

  def occurrence_attributes(overrides = {})
    {
      title: "Buraco na calçada",
      description: "Há um buraco grande na calçada perto da entrada.",
      category_id: (overrides.delete(:category) || create(:category)).id,
      location_source: "gps",
      latitude: "-8.0171234",
      longitude: "-34.9501234",
      requested_visibility: "internal"
    }.merge(overrides)
  end
end

RSpec.configure do |config|
  config.include SguSupport
  config.include ActiveSupport::Testing::TimeHelpers
end
