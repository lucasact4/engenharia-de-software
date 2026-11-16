require "active_storage/service/disk_service"
require "base64"
require "stringio"
require "tempfile"

class ActiveStorage::Service::EncryptedDiskService < ActiveStorage::Service::DiskService
  PREFIX = "SGU encrypted upload v1\n".b.freeze

  def upload(key, io, checksum: nil, **)
    bytes = io.read.b
    verify_checksum!(bytes, checksum)
    write_encrypted(path_for(key), bytes, key)
  end

  def download(key)
    bytes = read_file(path_for(key), key)
    return bytes unless block_given?

    yield bytes
  end

  def download_chunk(key, range)
    download(key).byteslice(range)
  end

  def compose(source_keys, destination_key, **)
    upload(destination_key, StringIO.new(source_keys.map { |key| download(key) }.join))
  end

  def migrate_file(key, checksum:)
    path = path_for(key)
    encrypted = encrypted_file?(path)
    bytes = encrypted ? read_file(path, key) : File.binread(path)
    verify_checksum!(bytes, checksum)
    write_encrypted(path, bytes, key) unless encrypted
  end

  def verify_snapshot_file(path, key, checksum:)
    raise ActiveStorage::IntegrityError unless encrypted_file?(path)

    verify_checksum!(read_file(path, key), checksum)
  end

  private

    def encrypted_file?(path)
      File.binread(path, PREFIX.bytesize) == PREFIX
    end

    def read_file(path, key)
      bytes = File.binread(path)
      raise ActiveStorage::IntegrityError unless bytes.start_with?(PREFIX)

      data = bytes.byteslice(PREFIX.bytesize..)
      Base64.strict_decode64(encryptor.decrypt_and_verify(data, purpose: key) || raise(ActiveStorage::IntegrityError))
    rescue Errno::ENOENT
      raise ActiveStorage::FileNotFoundError
    rescue ActiveSupport::MessageEncryptor::InvalidMessage, ArgumentError
      raise ActiveStorage::IntegrityError
    end

    def write_encrypted(path, bytes, key)
      directory = File.dirname(path)
      FileUtils.mkdir_p(directory)
      Tempfile.create("sgu-upload", directory, binmode: true) do |file|
        file.write(PREFIX)
        file.write(encryptor.encrypt_and_sign(Base64.strict_encode64(bytes), purpose: key))
        file.flush
        file.fsync
        file.close
        File.rename(file.path, path)
      end
    end

    def verify_checksum!(bytes, checksum)
      return if checksum.nil? || OpenSSL::Digest::MD5.base64digest(bytes) == checksum

      raise ActiveStorage::IntegrityError
    end

    def encryptor
      @encryptor ||= begin
        key = Rails.application.key_generator.generate_key("sgu/active-storage/encryption/v1", 32)
        ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm", serializer: JSON)
      end
    end
end
