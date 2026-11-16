require "rails_helper"
require "active_storage/service/encrypted_disk_service"
require "tmpdir"

RSpec.describe ActiveStorage::Service::EncryptedDiskService do
  it "encrypts new uploads and migrates older uploads in place with the checksum intact" do
    Dir.mktmpdir do |root|
      service = described_class.new(root: root)
      key = "0123456789abcdef"
      bytes = "\xFF\xD8\x00SGU".b
      sum = OpenSSL::Digest::MD5.base64digest(bytes)
      path = service.path_for(key)
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(path, bytes)

      expect { service.download(key) }.to raise_error(ActiveStorage::IntegrityError)
      service.migrate_file(key, checksum: sum)
      expect(File.binread(path)).not_to include(bytes)
      service.verify_snapshot_file(path, key, checksum: sum)
      expect(service.download(key)).to eq(bytes)

      service.upload(key, StringIO.new(bytes), checksum: sum)
      expect(service.download_chunk(key, 1..2)).to eq(bytes[1..2])
      expect(File.binread(path)).not_to include(bytes)
    end
  end
end
