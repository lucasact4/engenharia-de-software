require "rails_helper"
require "tmpdir"

RSpec.describe Backups::Snapshot do
  include ActiveSupport::Testing::TimeHelpers

  before do
    @root = Pathname(Dir.mktmpdir("sgu-backup-"))
    @uploads = @root.join("uploads")
    @destination = @root.join("backups")
    FileUtils.mkdir_p(@uploads)
    @databases = %w[primary cache queue cable].to_h { |name| [ name, @uploads.join("#{name}.sqlite3") ] }
    @connections = @databases.transform_values do |path|
      SQLite3::Database.new(path.to_s).tap do |database|
        database.execute("PRAGMA journal_mode=WAL")
        database.execute("PRAGMA wal_autocheckpoint=0")
        database.execute("CREATE TABLE sample (value TEXT)")
        database.execute("INSERT INTO sample VALUES ('recoverable')")
      end
    end
    @connections.fetch("primary").execute("CREATE TABLE active_storage_blobs (key TEXT, checksum TEXT, service_name TEXT)")
    disk = ActiveStorage::Service::DiskService.new(root: @uploads)
    allow(ActiveStorage::Blob.services).to receive(:fetch).with("test").and_return(disk)
    travel_to Time.utc(2026, 11, 5, 1)
  end

  after do
    travel_back
    @connections.each_value(&:close)
    FileUtils.remove_entry(@root)
  end

  def backup(**options)
    described_class.new(destination: @destination, databases: @databases, storage_path: @uploads, **options)
  end

  def add_upload(content = "original image")
    key = "abcdefghijklmnopqrstuv123456"
    path = @uploads.join(key[0, 2], key[2, 2], key)
    FileUtils.mkdir_p(path.dirname)
    File.binwrite(path, content)
    checksum = Base64.strict_encode64(Digest::MD5.digest(content))
    @connections.fetch("primary").execute("INSERT INTO active_storage_blobs VALUES (?, ?, ?)", [ key, checksum, "test" ])
    path
  end

  it "restores all four live WAL databases and original uploads from a complete, checksummed snapshot" do
    upload = add_upload
    expect(Pathname("#{@databases.fetch('primary')}-wal")).to exist
    result = backup.call
    manifest = JSON.parse(result.join("manifest.json").read)

    expect(manifest.fetch("databases").keys).to match_array(%w[primary cache queue cable])
    manifest.fetch("files").each do |relative, checksum|
      expect(Digest::SHA256.file(result.join(relative)).hexdigest).to eq(checksum)
    end
    restored = @root.join("restored")
    FileUtils.cp_r(result.join("storage"), restored)
    @databases.each do |_name, path|
      SQLite3::Database.open(restored.join(path.basename).to_s) do |database|
        expect(database.execute("PRAGMA integrity_check")).to eq([ [ "ok" ] ])
        expect(database.get_first_value("SELECT value FROM sample")).to eq("recoverable")
      end
    end
    expect(restored.join(upload.relative_path_from(@uploads)).binread).to eq("original image")
    expect(backup).to be_healthy
    expect(File.stat(result.join("manifest.json")).mode & 0o777).to eq(0o600)
    expect(@destination.glob(".partial-*")).to be_empty
  end

  it "runs once per fixed 48-hour UTC period, across month boundaries and restarts" do
    first = backup.call
    travel 24.hours
    expect(backup.call).to eq(:current)
    travel 24.hours
    expect(backup.call).to be_a(Pathname)
    expect(@destination.glob("sgu-*").size).to eq(2)
    expect(first).to exist

    travel_to Time.at((Time.utc(2026, 12, 1).to_i / described_class::PERIOD) * described_class::PERIOD).utc
    start = backup.call
    travel 24.hours
    expect(backup.call).to eq(:current)
    travel 24.hours
    expect(backup.call).not_to eq(start)
  end

  it "allows a manual backup within the same period" do
    expect(backup.call).to be_a(Pathname)
    expect(backup.call(force: true)).to be_a(Pathname)
    expect(@destination.glob("sgu-*").size).to eq(2)
  end

  it "prevents concurrent snapshots with a shared filesystem lock" do
    FileUtils.mkdir_p(@destination)
    File.open(@destination.join(".lock"), "w") do |lock|
      lock.flock(File::LOCK_EX)
      expect(backup.call).to eq(:running)
    end
    expect(@destination.glob("sgu-*")).to be_empty
  end

  it "preserves the last good backup, records a missing upload failure and retries the failed period" do
    first = backup.call
    travel 48.hours
    upload = add_upload
    File.unlink(upload)

    expect { backup.call }.to raise_error(Errno::ENOENT)
    expect(backup.status).to include("backup" => first.basename.to_s, "error_class" => "Errno::ENOENT")
    expect(backup.status.fetch("last_failure_at")).to be_present
    expect(backup).not_to be_healthy
    expect(@destination.glob("sgu-*")).to eq([ first ])
    expect(@destination.glob(".partial-*")).to be_empty

    File.binwrite(upload, "original image")
    expect(backup.call).to be_a(Pathname)
    expect(backup.status).not_to have_key("last_failure_at")
    expect(backup).to be_healthy
  end

  it "rejects corrupt uploads instead of publishing a broken recovery point" do
    File.binwrite(add_upload, "corrupt")
    expect { backup.call }.to raise_error(IOError, "Upload checksum mismatch")
    expect(@destination.glob("sgu-*")).to be_empty
    expect(backup.status).to include("error_class" => "IOError")
  end

  it "reports missing, stale and removed snapshots as unhealthy" do
    expect(backup).not_to be_healthy
    result = backup.call
    travel 49.hours
    expect(backup).not_to be_healthy
    travel_back
    travel_to Time.utc(2026, 11, 5, 1)
    File.unlink(result.join("manifest.json"))
    expect(backup).not_to be_healthy
  end

  it "refuses a destination inside the live storage tree, including a symlink" do
    expect { backup(destination: @uploads.join("backups")).call }.to raise_error(ArgumentError, /outside storage/)
    File.symlink(@uploads, @root.join("storage-link"))
    expect { backup(destination: @root.join("storage-link", "backups")).call }.to raise_error(ArgumentError, /outside storage/)
  end

  it "recreates a lost snapshot even when the period is marked successful" do
    result = backup.call
    FileUtils.remove_entry(result)
    expect(backup.call).to be_a(Pathname)
    expect(backup).to be_healthy
  end

  it "rejects a damaged SQLite database without publishing a partial backup" do
    @databases["damaged"] = @uploads.join("damaged.sqlite3")
    File.binwrite(@databases.fetch("damaged"), "not a SQLite database")
    expect { backup.call }.to raise_error(SQLite3::Exception)
    expect(@destination.glob("sgu-*")).to be_empty
    expect(@destination.glob(".partial-*")).to be_empty
  end

  it "does not silently create an empty database when an expected source is missing" do
    @databases["missing"] = @uploads.join("missing.sqlite3")
    expect { backup.call }.to raise_error(Errno::ENOENT)
    expect(@databases.fetch("missing")).not_to exist
    expect(@destination.glob("sgu-*")).to be_empty
  end
end
