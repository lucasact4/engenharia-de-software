require "digest"
require "fileutils"
require "json"
require "tmpdir"
require "sqlite3"

module Backups
  class Restore
    def initialize(snapshot:, destination:)
      @snapshot = Pathname(snapshot).realpath
      @destination = Pathname(destination).expand_path
    end

    def call
      manifest = JSON.parse(@snapshot.join("manifest.json").read)
      raise IOError, "Unsupported backup format" unless manifest.fetch("format") == "sgu-encrypted-v1"
      raise IOError, "Unexpected backup identity" unless manifest.fetch("snapshot") == @snapshot.basename.to_s
      raise ArgumentError, "Restore destination must not exist" if @destination.exist? || @destination.symlink?

      payload = Payload.new
      staging = Pathname(Dir.mktmpdir(".sgu-restore-", @destination.dirname))
      begin
        manifest.fetch("files").each do |relative, checksum|
          source = checked_source(relative)
          raise IOError, "Backup checksum mismatch" unless Digest::SHA256.file(source).hexdigest == checksum

          target = staging.join(relative)
          FileUtils.mkdir_p(target.dirname, mode: 0o700)
          File.open(target, "wb", 0o600) do |output|
            payload.open(source, "#{manifest.fetch('snapshot')}/#{relative}", output)
          end
        end
        manifest.fetch("databases").each_value do |relative|
          raise IOError, "Missing database in backup" unless manifest.fetch("files").key?(relative)

          SQLite3::Database.open(staging.join(relative).to_s, readonly: true) do |database|
            raise IOError, "Restored database failed integrity check" unless database.get_first_value("PRAGMA integrity_check") == "ok"
          end
        end
        File.rename(staging, @destination)
      ensure
        FileUtils.remove_entry(staging) if staging.directory?
      end
      @destination
    end

    private

      def checked_source(relative)
        parts = relative.split("/")
        raise IOError, "Invalid backup path" unless parts.first == "storage" && parts.size > 1 &&
          parts.all? { |part| part.match?(/\A[A-Za-z0-9_.-]+\z/) && !%w[. ..].include?(part) }

        source = @snapshot.join(relative).realpath
        raise IOError, "Invalid backup path" unless source.ascend.include?(@snapshot)

        source
      end
  end
end
