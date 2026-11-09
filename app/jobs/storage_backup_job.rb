class StorageBackupJob < ApplicationJob
  queue_as :backups
  retry_on StandardError, wait: 5.minutes, attempts: 3

  def perform
    Backups::Snapshot.call
  rescue StandardError => error
    Rails.error.report(error, handled: false, source: "sgu.backup")
    raise
  end
end
