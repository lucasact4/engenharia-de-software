require "active_storage/service/disk_service"
require "base64"
require "digest"
require "fileutils"
require "json"
require "securerandom"
require "sqlite3"

module Backups
  class Snapshot < ApplicationService
    PERIOD = 48.hours.to_i

    def initialize(destination: ENV.fetch("SGU_BACKUP_PATH") { Rails.root.join("backups") },
                   databases: nil, storage_path: nil, now: Time.current)
      @destination = Pathname(destination).expand_path
      @databases = databases || configured_databases
      @storage_path = Pathname(storage_path || local_storage_path).expand_path
      @now = now.utc
    end

    def call(force: false)
      prepare_destination!
      File.open(@destination.join(".lock"), File::RDWR | File::CREAT, 0o600) do |lock|
        return :running unless lock.flock(File::LOCK_EX | File::LOCK_NB)

        state = status
        return :current if !force && state["period_start"] == period_start.iso8601 && healthy?

        create_snapshot(state)
      end
    end

    def status
      file = @destination.join("status.json")
      file.exist? ? JSON.parse(file.read) : {}
    end

    def healthy?
      state = status
      state["completed_at"].present? && state["last_failure_at"].nil? &&
        Time.iso8601(state.fetch("completed_at")) >= @now - PERIOD &&
        @destination.join(state.fetch("backup"), "manifest.json").file?
    end

    private

      def configured_databases
        ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).to_h do |config|
          raise ArgumentError, "Backup requires SQLite databases" unless config.adapter == "sqlite3"

          [ config.name, Pathname(config.database).expand_path(Rails.root) ]
        end
      end

      def local_storage_path
        service = ActiveStorage::Blob.service
        raise ArgumentError, "Backup requires local Active Storage" unless service.is_a?(ActiveStorage::Service::DiskService)

        service.root
      end

      def prepare_destination!
        FileUtils.mkdir_p(@destination, mode: 0o700)
        @destination = @destination.realpath
        source = @storage_path.realpath
        if @destination == source || @destination.to_s.start_with?("#{source}/")
          raise ArgumentError, "Backup destination must be outside storage"
        end
      end

      def period_start
        Time.at((@now.to_i / PERIOD) * PERIOD).utc
      end

      def create_snapshot(state)
        name = "sgu-#{@now.strftime('%Y%m%dT%H%M%S')}-#{SecureRandom.hex(8)}"
        staging = @destination.join(".partial-#{name}")
        FileUtils.mkdir_p(staging.join("storage"), mode: 0o700)
        database_files = copy_databases(staging)
        copy_uploads(staging, database_files.fetch("primary"))
        manifest = {
          environment: Rails.env, started_at: @now.iso8601, period_start: period_start.iso8601,
          databases: database_files, files: payload_checksums(staging)
        }
        write_json(staging.join("manifest.json"), manifest)
        File.rename(staging, @destination.join(name))
        write_json(@destination.join("status.json"), {
          backup: name, completed_at: Time.current.utc.iso8601, period_start: period_start.iso8601
        })
        Rails.logger.info("[backup] completed #{name}")
        @destination.join(name)
      rescue StandardError => error
        write_json(@destination.join("status.json"), state.merge(
          "last_failure_at" => Time.current.utc.iso8601, "error_class" => error.class.name
        ))
        raise
      ensure
        FileUtils.remove_entry(staging) if staging&.directory?
      end

      def copy_databases(staging)
        raise ArgumentError, "A primary database is required" unless @databases.key?("primary")

        filenames = @databases.values.map { |file| Pathname(file).basename.to_s }
        raise ArgumentError, "Database filenames must be unique" unless filenames.uniq == filenames

        @databases.to_h do |name, file|
          source = Pathname(file)
          raise Errno::ENOENT, "Missing #{name} database" unless source.file?

          relative = "storage/#{source.basename}"
          copy_database(source, staging.join(relative))
          [ name, relative ]
        end
      end

      def copy_database(source_path, destination_path)
        source = SQLite3::Database.new(source_path.to_s, readonly: true)
        target = SQLite3::Database.new(destination_path.to_s)
        File.chmod(0o600, destination_path)
        backup = SQLite3::Backup.new(target, "main", source, "main")
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 300
        loop do
          result = backup.step(256)
          break if result == SQLite3::Constants::ErrorCode::DONE
          unless [ SQLite3::Constants::ErrorCode::OK, SQLite3::Constants::ErrorCode::BUSY,
                   SQLite3::Constants::ErrorCode::LOCKED ].include?(result)
            raise SQLite3::Exception, "SQLite backup failed (#{result})"
          end
          raise SQLite3::BusyException, "SQLite backup timed out" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

          sleep(0.05) unless result == SQLite3::Constants::ErrorCode::OK
        end
        backup.finish
        backup = nil
        raise SQLite3::Exception, "Backup integrity check failed" unless target.execute("PRAGMA integrity_check") == [ [ "ok" ] ]
      ensure
        backup&.finish
        target&.close
        source&.close
      end

      def copy_uploads(staging, primary)
        SQLite3::Database.open(staging.join(primary).to_s, readonly: true) do |database|
          database.execute("SELECT key, checksum, service_name FROM active_storage_blobs") do |key, checksum, service_name|
            service = ActiveStorage::Blob.services.fetch(service_name)
            unless service.is_a?(ActiveStorage::Service::DiskService) && Pathname(service.root).expand_path == @storage_path
              raise ArgumentError, "All uploads must use the backed-up local storage"
            end
            raise ArgumentError, "Invalid upload key" unless key.match?(/\A[a-zA-Z0-9_-]{5,}\z/)

            relative = Pathname(key[0, 2]).join(key[2, 2], key)
            source = @storage_path.join(relative).realpath
            raise ArgumentError, "Upload must be inside storage" unless source.to_s.start_with?("#{@storage_path.realpath}/")

            target = staging.join("storage", relative)
            FileUtils.mkdir_p(target.dirname, mode: 0o700)
            FileUtils.copy_file(source, target)
            File.chmod(0o600, target)
            unless Base64.strict_encode64(Digest::MD5.file(target).digest) == checksum
              raise IOError, "Upload checksum mismatch"
            end
          end
        end
      end

      def payload_checksums(staging)
        staging.glob("storage/**/*").select(&:file?).to_h do |file|
          [ file.relative_path_from(staging).to_s, Digest::SHA256.file(file).hexdigest ]
        end
      end

      def write_json(path, value)
        temporary = Pathname("#{path}.#{SecureRandom.hex(8)}.tmp")
        File.write(temporary, JSON.pretty_generate(value) + "\n", mode: "w", perm: 0o600)
        File.rename(temporary, path)
      ensure
        FileUtils.rm_f(temporary) if temporary
      end
  end
end
