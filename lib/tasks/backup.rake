namespace :sgu do
  namespace :backup do
    desc "Create an integrity-checked SQLite and local upload backup"
    task create: :environment do
      puts Backups::Snapshot.new.call(force: true)
    end

    desc "Show backup status; fail if missing, failed, or older than 48 hours"
    task status: :environment do
      backup = Backups::Snapshot.new
      puts JSON.pretty_generate(backup.status)
      abort "Backup is missing, failed, or stale" unless backup.healthy?
    end
  end
end
