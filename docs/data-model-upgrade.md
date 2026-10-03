# Upgrading an Existing Database to the SGU Data Model

This guide explains how to apply the SGU data-model migrations and subsequent presentation/registration changes to an existing SQLite database, and what a rollback can and cannot undo. Legacy accounts and sessions are preserved; the demonstration table is intentionally removed. It covers local and shared non-production databases. Production backup policy stays in [Backing up and restoring SQLite production data](sqlite-backup-and-restore.md); never run this procedure against production as an experiment.

## What the upgrade changes

The current upgrade consists of twelve migrations after baseline version `20260914150000`, applied in this order:

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
| `20261002120000_create_presentation_profiles.rb` | Creates saved presentation profiles. |
| `20261003100000_remove_legacy_dogs.rb` | Removes the demonstration table and its rows. Its rollback recreates an empty table; it cannot recover the removed data. |
| `20261003100100_add_registration_review_to_users.rb` | Adds registration status, requested role, review metadata, reviewer foreign key, and nullable `email_verified_at`. Existing accounts default to `approved`; CHECK constraints restrict registration statuses and public signup roles. |

Existing account data is preserved: `users` (`id`, `email_address`, `password_digest`, `admin`, `deleted_at`) and `sessions`. The former `dogs` table is intentionally removed by a later migration; back it up before upgrading if its demonstration rows matter. The historical creation migration and legacy schema fixture remain so existing databases can be upgraded faithfully. New profile fields start as `NULL` and `public_profile` starts as `false`. No roles are inferred from existing accounts; `users.admin` remains the only source of administrator access. The `locations` catalog intentionally starts empty because no official campus locations have been provided.

`spec/db/migration_upgrade_spec.rb` exercises real migrations against temporary SQLite databases, compares preserved account/session data and the dumped schema, and rolls back to explicit versions. It also checks the publication-restriction backfill while preserving historical alerts. Use its current assertions as the executable upgrade contract.

## 1. Record the current state and back up

Stop or pause anything that writes to the database if you can. Then record the current schema version:

```bash
sqlite3 storage/development.sqlite3 "select max(version) from schema_migrations;"
```

The baseline for this upgrade is schema version `20260914150000`. If the database reports another version, review pending and applied migrations before using the explicit rollback target below.

Create a consistent backup with the SQLite online backup API. It is safe with WAL mode; do not copy the `.sqlite3` file alone while the application is running.

```bash
mkdir -p tmp/backups
sqlite3 storage/development.sqlite3 ".backup 'tmp/backups/development-YYYYMMDD-before-card6.sqlite3'"
sqlite3 tmp/backups/development-YYYYMMDD-before-card6.sqlite3 "pragma integrity_check;"
```

The integrity check must print `ok`. Compare a few row counts between the source and the backup, for example:

```bash
sqlite3 storage/development.sqlite3 "select 'users', count(*) from users union all select 'sessions', count(*) from sessions;"
sqlite3 tmp/backups/development-YYYYMMDD-before-card6.sqlite3 "select 'users', count(*) from users union all select 'sessions', count(*) from sessions;"
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

A database already at `20261001120700` applies the publication block migration and all later pending migrations. A database at `20261002120000` applies the demonstration-table removal and registration-review migrations. The publication block migration leaves existing publication states unchanged: the publication policy scope excludes content whose source is blocked from non-administrator reads, preserving the historical state. Through the application, `Alerts::Restrict` preserves the author's requested audience, sets the block, and withdraws any published projection. Releasing the block through `Alerts::ChangeAudience` requires an administrator and a reason; publication still follows the usual editorial approval flow.

## 4. Verify

```bash
sqlite3 storage/development.sqlite3 "select count(*) from roles;"
sqlite3 storage/development.sqlite3 "select count(*) from categories;"
sqlite3 storage/development.sqlite3 "pragma integrity_check;"
sqlite3 storage/development.sqlite3 "pragma foreign_key_check;"
```

With no preexisting catalogs, expect `7` roles, `7` categories, `ok` from the integrity check, and no output from the foreign key check. Existing extra catalog entries are preserved, so their counts may be higher. Compare the row counts recorded in step 1 for `users` and `sessions`. Existing accounts must have `registration_status = 'approved'`, nullable review metadata, and unchanged credentials and administrator flags. Existing `deleted_at` values remain effective even for approved accounts. The following query must return no rows after the removal migration:

```bash
sqlite3 storage/development.sqlite3 "select name from sqlite_master where type = 'table' and name = 'dogs';"
```

`email_verified_at` remains `NULL`: adding the column does not verify email ownership. See the [registration guide](sgu-cadastro-temas-revisao.md) for temporary automatic approval and administrative review.

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
bin/rails db:migrate VERSION=20260914150000
```

From the current schema, this explicit target removes registration-review fields, saved presentation profiles, the publication block, SGU tables, and profile columns. Everything created after the baseline is lost: alerts, publications, comments, granted roles, audit events, attachment metadata, and profile data. Rolling back the demonstration-table removal recreates only its structure, with no rows. Active Storage files on disk are not deleted, and the bootstrap data migration's `down` does nothing. Do not use a fixed `STEP` count across versions: later migrations change what it would undo.

To recover data, restore the backup taken before migrating, together with the matching storage files. Stop all application processes first, then run:

```bash
sqlite3 storage/development.sqlite3 ".restore 'tmp/backups/development-YYYYMMDD-before-card6.sqlite3'"
```

Repeat the integrity check and row counts from step 1 after restoring.

## Idempotency compatibility

Alert creation now preserves leading zeros in numeric-looking titles and descriptions when calculating the request digest; numeric normalization applies only to numeric attributes. Replaying an older key whose digest used the previous normalization can return a conservative idempotency conflict. It does not create a duplicate alert; check the existing record before using another key.

## Operational notes for attachments

- Default Active Storage routes are disabled (`config.active_storage.draw_routes = false` in `config/application.rb`). Alert photos are served only through `GET /alertas/:alert_id/fotos/:id` (`AlertPhotosController`), which re-checks authorization and returns 404 when access is denied. `DELETE` on the same path (`Alerts::RemovePhoto`) removes one attachment of that alert: the attachment row is deleted and audited in a transaction, and the file is purged by a background job only after the commit.
- Alert photos accept PNG or JPEG, verified by file signature, with at most 5 photos of 5 MiB (5 × 1024 × 1024 bytes) each. The `image_processing` gem is not installed, so no variants are generated.
- Because attachment metadata lives in the database and the files live under `storage/`, back up and restore both together.
