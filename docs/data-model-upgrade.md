# Upgrading an Existing Database to the SGU Data Model

This guide explains how to apply the SGU card #6 data-model migrations to an existing SQLite database while preserving legacy rows, and what a rollback can and cannot undo. It covers local and shared non-production databases. Production backup policy stays in [Backing up and restoring SQLite production data](sqlite-backup-and-restore.md); never run this procedure against production as an experiment.

## What the upgrade changes

The upgrade consists of nine migrations, applied in this order:

| Migration | Effect |
| --- | --- |
| `20261001120000_add_profile_fields_to_users.rb` | Adds nullable `display_name`, `username`, and `bio`, plus required `public_profile` (default `false`), to `users`. Rebuilds the table through a SQLite table copy to add CHECK constraints. |
| `20261001120100_create_roles_and_catalogs.rb` | Creates `roles`, `user_roles`, `categories`, and `locations`. |
| `20261001120200_bootstrap_roles_and_categories.rb` | Data migration. Inserts 7 roles and 7 categories by `code`. Idempotent; its `down` intentionally does nothing. |
| `20261001120300_create_alerts.rb` | Creates `alerts`. |
| `20261001120400_create_publications.rb` | Creates `publications`. |
| `20261001120500_create_audit_events.rb` | Creates `audit_events`. |
| `20261001120600_create_social_tables.rb` | Creates comments, likes, bookmarks, follows, subscriptions, and reports. |
| `20261001120700_create_active_storage_tables.rb` | Creates the Active Storage tables missing from the previous schema: the three 2024 `*.active_storage.rb` migrations only update tables when they already exist. Uses `if_not_exists`; its `down` drops the three tables. |
| `20261002070000_add_publication_block_to_alerts.rb` | Adds required `publication_blocked` (default `false`) with a boolean CHECK constraint. Backfills previously audited restrictions whose latest restriction/audience event (by audit ID) is `alert.restricted`. |

Existing data is preserved: `users` (`id`, `email_address`, `password_digest`, `admin`, `deleted_at`), `sessions`, and `dogs`. New profile fields start as `NULL` and `public_profile` starts as `false`. No roles are inferred from existing accounts; `users.admin` remains the only source of administrator access. The `locations` catalog intentionally starts empty because no official campus locations have been provided.

`spec/db/migration_upgrade_spec.rb` checks this behavior: it runs the real migrations against a temporary SQLite database, compares rows before and after, compares the dumped schema with `db/schema.rb`, and rolls back all nine migrations. A separate case upgrades from `20261001120700` with three existing alerts and audit events, checks the restriction backfill, and rolls back only the ninth migration while preserving those alerts.

## 1. Record the current state and back up

Stop or pause anything that writes to the database if you can. Then record the current schema version:

```bash
sqlite3 storage/development.sqlite3 "select max(version) from schema_migrations;"
```

The baseline for this upgrade is schema version `20260914150000`. If the database reports another version, review pending and applied migrations before following the nine-migration rollback described below.

Create a consistent backup with the SQLite online backup API. It is safe with WAL mode; do not copy the `.sqlite3` file alone while the application is running.

```bash
mkdir -p tmp/backups
sqlite3 storage/development.sqlite3 ".backup 'tmp/backups/development-YYYYMMDD-before-card6.sqlite3'"
sqlite3 tmp/backups/development-YYYYMMDD-before-card6.sqlite3 "pragma integrity_check;"
```

The integrity check must print `ok`. Compare a few row counts between the source and the backup, for example:

```bash
sqlite3 storage/development.sqlite3 "select 'users', count(*) from users union all select 'sessions', count(*) from sessions union all select 'dogs', count(*) from dogs;"
sqlite3 tmp/backups/development-YYYYMMDD-before-card6.sqlite3 "select 'users', count(*) from users union all select 'sessions', count(*) from sessions union all select 'dogs', count(*) from dogs;"
```

`tmp/` is ignored by Git. Keep backups of shared databases somewhere outside the working copy as well.

If local Active Storage files exist under `storage/` (Disk service, see `config/storage.yml`), back them up at the same time as the database. Attachment rows and their files must always be restored together.

## 2. Rehearse on an isolated copy

Before touching a shared database, run the migrations against a copy. `DATABASE_URL` overrides `config/database.yml`, and `SCHEMA` keeps the rehearsal from rewriting `db/schema.rb`:

```bash
cp tmp/backups/development-YYYYMMDD-before-card6.sqlite3 tmp/rehearsal.sqlite3
DATABASE_URL=sqlite3:$PWD/tmp/rehearsal.sqlite3 SCHEMA=tmp/rehearsal-schema.rb bin/rails db:migrate
```

Use an absolute path in `DATABASE_URL`. Run the checks from step 4 against `tmp/rehearsal.sqlite3` before continuing.

## 3. Apply the migrations

```bash
bin/rails db:migrate
```

A database already at `20261001120700` applies only the new `20261002070000` migration. It leaves existing publication states unchanged: the publication policy scope excludes content whose source is blocked from non-administrator reads, preserving the historical state. Through the application, `Alerts::Restrict` preserves the author's requested audience, sets the block, and withdraws any published projection. Releasing the block through `Alerts::ChangeAudience` requires an administrator and a reason; publication still follows the usual editorial approval flow.

## 4. Verify

```bash
sqlite3 storage/development.sqlite3 "select count(*) from roles;"
sqlite3 storage/development.sqlite3 "select count(*) from categories;"
sqlite3 storage/development.sqlite3 "pragma integrity_check;"
sqlite3 storage/development.sqlite3 "pragma foreign_key_check;"
```

With no preexisting catalogs, expect `7` roles, `7` categories, `ok` from the integrity check, and no output from the foreign key check. Existing extra catalog entries are preserved, so their counts may be higher. Compare the row counts recorded in step 1 for `users`, `sessions`, and `dogs`.

## Catalogs outside migrations

After the catalog tables exist, missing roles and categories can be inserted without rerunning migrations:

```bash
bin/rails sgu:catalogs:bootstrap
```

The task (`lib/tasks/sgu.rake`, service `app/services/catalogs/bootstrap.rb`) is idempotent. It inserts only missing codes, never changes edited names, never reactivates deactivated entries, and never touches users.

- A database created with `bin/rails db:schema:load` has **no** catalogs, because schema loading skips data migrations. Run the task afterward.
- `bin/rails db:prepare` on a brand-new database loads the schema and runs `db/seeds.rb`, which calls the same bootstrap, so catalogs are created.
- `db/seeds.rb` runs the bootstrap in every environment, but in development it then resets the two demo accounts (password, admin flag, and reactivation). Do not run `bin/rails db:seed` on a shared database just to get catalogs; use the task instead.

## Rollback limits

A rollback is structural, not a restore. Run it only on disposable databases:

```bash
bin/rails db:rollback STEP=9
```

From schema version `20261002070000`, this command removes the publication block, then drops the new tables and the profile columns. Everything created after the upgrade is lost: alerts, publications, comments, granted roles, audit events, attachment metadata, and profile data. Active Storage files on disk are not deleted, and the bootstrap data migration's `down` does nothing.

To recover data, restore the backup taken before migrating, together with the matching storage files. Stop all application processes first, then run:

```bash
sqlite3 storage/development.sqlite3 ".restore 'tmp/backups/development-YYYYMMDD-before-card6.sqlite3'"
```

Repeat the integrity check and row counts from step 1 after restoring.

## Idempotency compatibility

Alert creation now preserves leading zeros in numeric-looking titles and descriptions when calculating the request digest; numeric normalization applies only to numeric attributes. Replaying an older key whose digest used the previous normalization can return a conservative idempotency conflict. It does not create a duplicate alert; check the existing record before using another key.

## Operational notes for attachments

- Default Active Storage routes are disabled (`config.active_storage.draw_routes = false` in `config/application.rb`). Alert photos are served only through `GET /alertas/:alert_id/fotos/:id` (`AlertPhotosController`), which re-checks authorization and returns 404 when access is denied.
- Alert photos accept PNG or JPEG, verified by file signature, with at most 5 photos of 5 MiB (5 × 1024 × 1024 bytes) each. The `image_processing` gem is not installed, so no variants are generated.
- Because attachment metadata lives in the database and the files live under `storage/`, back up and restore both together.
