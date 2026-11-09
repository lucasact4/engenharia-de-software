require "rails_helper"
require "fugit"

RSpec.describe StorageBackupJob, type: :job do
  include ActiveJob::TestHelper

  it "reports a failed backup and schedules its retry on the backups queue" do
    error = IOError.new("Backup storage unavailable")
    allow(Backups::Snapshot).to receive(:call).and_raise(error)
    allow(Rails.error).to receive(:report)

    expect { described_class.perform_now }.to have_enqueued_job(described_class).on_queue("backups")
    expect(Rails.error).to have_received(:report).with(error, handled: false, source: "sgu.backup")
  end

  it "uses a supported hourly UTC schedule to check the durable 48-hour period" do
    task = YAML.load_file(Rails.root.join("config/recurring.yml")).fetch("production").fetch("storage_backup")
    cron = Fugit.parse(task.fetch("schedule"))
    first = cron.next_time(Time.utc(2026, 10, 31, 23)).to_t
    expect(cron).to be_a(Fugit::Cron)
    expect(first).to eq(Time.utc(2026, 11, 1))
    expect(task.fetch("class").constantize).to eq(described_class)
    expect(task.fetch("queue")).to eq("backups")
  end
end
