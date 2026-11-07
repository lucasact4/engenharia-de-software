# Automatic SQLite Backups and Recovery (RNF007)

SGU creates a recoverable copy of its SQLite databases and original local uploads in each fixed 48-hour UTC period. `StorageBackupJob` runs through Solid Queue and delegates to `Backups::Snapshot`. This implements the backup mechanism; production scheduling, storage access, and monitoring must be operational before relying on it.

## Schedule and worker

`config/recurring.yml` schedules the production job hourly on the `backups` queue. Each execution checks the current 48-hour period, anchored to the Unix epoch, and skips it if a backup has already succeeded in that period. The first check without a successful backup creates one. Missed periods do not create a backlog of historical copies: after a restart, the next execution backs up the current state.

The production configuration uses Solid Queue with its separate queue database. Kamal enables its supervisor inside Puma through `SOLID_QUEUE_IN_PUMA`. For a deployment that uses a separate worker instead, run `bin/jobs` with the same application release, database configuration, storage mounts, and backup destination. Do not disable the scheduler or leave the `backups` queue unconsumed.

Snapshot creation failures are recorded in the backup status; job errors are logged and reported through `Rails.error`. The job retries after five minutes, up to three attempts. A later recurring execution can try again if the period still has no successful backup. Connect the application's error reporting and status check to the operations team's monitoring; the implementation does not configure an external notification provider.

## Destination and contents

`SGU_BACKUP_PATH` selects the destination directory; its default is `Rails.root/backups`. It must be outside the application storage directory. The production image uses `/rails/backups`, persisted by a separate volume in `config/deploy.yml`. Give the application user write access and keep access restricted to the recovery team.

Each completed snapshot contains:

- `storage/`: online SQLite copies of all databases configured for the current environment, plus the original local Active Storage files referenced by the copied primary database;
- `manifest.json`: snapshot metadata and SHA-256 hashes of the payload files.

Production includes the primary, Solid Cache, Solid Queue, and Solid Cable databases from `config/database.yml`. Each SQLite copy is made through the online backup API and checked with `PRAGMA integrity_check`; live database files, WAL files, and shared-memory files are not copied casually. These are separate database snapshots, not one transaction spanning all databases.

Upload references come from the primary database snapshot. Original file checksums are checked against that metadata. A missing or changed original fails the backup instead of publishing a copy with missing evidence. Files outside the snapshot's blob references are not included; image variants and previews can be regenerated when necessary. This implementation supports local disk uploads; do not assume it backs up files from an external Active Storage service.

A file lock prevents concurrent backup runs from publishing overlapping copies. A snapshot is published only after all checks pass, by renaming its temporary directory. `status.json` records the latest successful directory, completion time, UTC period, and any subsequent snapshot creation failure independently of the live database. A successful run clears the recorded failure. Backup contents are not committed to Git. There is no automatic retention deletion; monitor capacity and define a retention policy before production use.

The default volume remains on the application host. It survives container replacement but does not protect against host loss. Mount an encrypted destination managed outside that host, or replicate completed snapshots to a controlled remote backup system. Record the owner, encryption, access controls, retention, and replication failure alerts. The application does not provision a cloud backup provider or encrypt its output itself.

## Run and monitor

Run these commands inside the application environment, with its normal credentials and storage mounts:

```bash
RAILS_ENV=production bin/rails sgu:backup:create
RAILS_ENV=production bin/rails sgu:backup:status
```

`sgu:backup:create` requests a snapshot immediately, even if the current automatic period already has a successful one. It does not require waiting for the recurring job. The status command prints the persisted backup status and exits unsuccessfully when the backup is missing, has a recorded failure, or the latest success is more than 48 hours old. Check it from external monitoring independently of the backup worker, so a stopped scheduler can be detected too.

For a non-default destination, supply the same `SGU_BACKUP_PATH` to the web process, worker, manual commands, and monitoring check. Record the application Git commit or image tag alongside each retained backup. Keep the Rails master key, database encryption keys, and other recovery credentials in a separate protected secret store: a database backup without the required keys may be unusable.

## Restore procedure

Perform the first restore in an isolated non-production environment. For a production recovery, use the rehearsed procedure during a maintenance window. Preserve existing data until the recovery owner approves replacement.

1. Choose a completed snapshot, inspect its manifest, and verify every payload file against the recorded SHA-256 hash. Do not restore from a temporary or failed snapshot.
2. Prepare the matching application release and the original database encryption credentials. Confirm the database filenames and storage paths match the target environment.
3. Stop all web processes, workers, and other writers before restoring. Inspect the queued jobs in the recovery copy before starting workers, because restoring the queue can make previously executed work eligible again.
4. Restore the snapshot's `storage/` contents into an empty recovery storage directory, preserving the recorded layout. Do not overlay the backup onto live databases or leave old SQLite WAL/SHM sidecars beside the restored files.
5. Check each restored SQLite database with `PRAGMA integrity_check`; require `ok`. Start the application and apply any deliberately planned migrations only after confirming release compatibility.
6. Verify application records, authentication, original uploads, and operational flows. Regenerate image derivatives when needed, then restart job processing after reviewing the restored queue.
7. Record the recovery duration, checks, and corrective actions. Resume automatic backups and confirm that a new snapshot succeeds.

Rehearse restoration before launch, after changes to the backup mechanism or destination, and at an interval agreed by the recovery owner. A successful backup job alone does not prove that the deployed recovery procedure works.

## Related guides

- [SQLite in production](sqlite-production.md)
- [First deployment checklist](first-deploy.md)
- [Migrating from SQLite to PostgreSQL](sqlite-to-postgresql.md)
