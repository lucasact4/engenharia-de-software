require "active_support/message_encryptor"
require "fileutils"
require "pathname"
require "base64"
require "json"

module Backups
  # Each payload is authenticated in chunks so even large SQLite files can be sealed.
  class Payload
    CHUNK_BYTES = 1.megabyte
    MAX_FRAME_BYTES = 2 * CHUNK_BYTES
    PURPOSE = "sgu-backup-v1"

    def initialize
      key = Rails.application.key_generator.generate_key(PURPOSE, 32)
      @encryptor = ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm", serializer: JSON)
    end

    def seal(path, context)
      temporary = Pathname("#{path}.seal")
      File.open(temporary, "wb", 0o600) do |output|
        File.open(path, "rb") do |input|
          index = 0
          while (chunk = input.read(CHUNK_BYTES))
            write_frame(output, Base64.strict_encode64(chunk), context, index)
            index += 1
          end
          write_frame(output, "end", context, index)
        end
      end
      File.rename(temporary, path)
    ensure
      FileUtils.rm_f(temporary) if temporary
    end

    def open(path, context, output)
      File.open(path, "rb") do |input|
        index = 0
        loop do
          line = input.gets(MAX_FRAME_BYTES)
          raise IOError, "Invalid backup frame" unless line&.end_with?("\n")

          value = @encryptor.decrypt_and_verify(line.chomp, purpose: "#{context}/#{index}")
          raise IOError, "Invalid backup payload" unless value

          if value == "end"
            raise IOError, "Unexpected data after backup payload" unless input.eof?

            break
          end
          output.write(Base64.strict_decode64(value))
          index += 1
        end
      end
    rescue ActiveSupport::MessageEncryptor::InvalidMessage, ArgumentError
      raise IOError, "Invalid backup payload"
    end

    private

      def write_frame(output, value, context, index)
        output.puts(@encryptor.encrypt_and_sign(value, purpose: "#{context}/#{index}"))
      end
  end
end
