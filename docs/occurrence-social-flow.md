# Occurrence Posts, Public Review, and Verification

An occurrence is written once by its author. The same post appears in the internal feed and, when authorized, in the public feed. Administrators review the content already submitted; they do not create a second title, description, or set of images.

This guide describes the occurrence-publication refactor. For account registration and theme maintenance, see [Registration, account review, and themes](sgu-cadastro-temas-revisao.md) (Portuguese). For existing databases, read [the upgrade guide](data-model-upgrade.md) before migrating. The earlier [CRUD implementation report](alertas-crud-implementacao.md) (Portuguese) is historical where its editorial occurrence workflow differs from this guide.

## Data ownership and boundaries

- `Alert` owns the explicit title, description, category, location, original photos, photo order, and operational handling data. The author form requires a title of 5–160 characters and a description of 10–5,000 characters. Editing only the description preserves the existing title. `Alert.title_from` remains a creation fallback for older programmatic callers that omit the title key entirely; an explicitly blank title is rejected. `Publication` never duplicates this title or description.
- `Publication` owns the post identity, audience, approval decision, content version, moderation block, and social interactions. There is at most one publication per source alert. For occurrences, stored `publications.title` and `body` are `NULL`; readers obtain canonical content through the model and `PublicationProjection`.
- Approval changes this existing publication. Comments, replies, likes, bookmarks, subscriptions, and reports keep the same publication ID across edits, rejection, and a change of audience.
- News and notices keep their own editorial content and administrator workflow. A panic alert does not become a feed post. A private occurrence has no public/internal feed disclosure.
- Operational alert access remains separate from feed access: seeing a post does not grant access to the original evidence, coordinates, accuracy, protocol, internal notes, or account email.

## Author and administrator behavior

| Author choice | Current author status | Result |
| --- | --- | --- |
| Internal | Any active account | Published immediately for active signed-in accounts; no manual review. |
| Public | No verification badge | The same post is published internally with a pending external review. Anonymous readers cannot see it. |
| Public | Administrator-granted verification badge | The same post is approved and published externally immediately, with approval origin `verified_author`. |
| Private | Any active account | Kept outside the feed, available only through authorized occurrence/handling access. |

The rule includes student accounts and uses the existing active-account authorization model. The badge does not create another institutional role or grant administration.

At `/admin/publicacoes`, the administrator opens the pending occurrence and sees its existing post. **Approve** makes that post externally visible immediately. **Do not approve** requires a reason and leaves the ordinary post internal. There is no extra publish step or editable duplicate content in this review form. An outdated content version or lock version is rejected so a review cannot approve content changed after it was displayed.

The rejection reason is available to the author in their occurrence detail and their own post data, not to other feed readers. The author may edit the occurrence or select public visibility again to resubmit. Text edits and changes to the photo selection, cover, or order update the canonical source and invalidate the previous external approval. For an unverified author, the updated post returns to internal visibility with a pending review. A verified author receives approval for the updated content version automatically.

An administrator can also remove a post for moderation with a reason. Editing, requesting external visibility, or receiving a badge does not clear either an alert disclosure restriction or a publication moderation block. Removing a post preserves the record and its interaction/history IDs.

## Verification badge

The administrator grants or removes verification at `/admin/users/:id`, through `PATCH /admin/users/:id/verificacao`. `Users::ChangeVerification` and `UserVerificationPolicy` enforce this operation server-side and record an audit event. Only an active administrator may change another active account; ordinary profile updates cannot set verification fields.

`users.verified_at` and `verified_by_id` are a matched pair. This badge is independent of `email_verified_at`, registration approval, and `users.admin`. New registrations and upgraded accounts do not receive it automatically. Account activation and a matching institutional email address do not prove email ownership; email confirmation is still unimplemented.

Granting or removing the badge affects later requests and edits. It does not automatically publish existing pending requests or withdraw already approved posts. The author can resubmit an existing request after receiving the badge. Moderation restrictions continue to apply.

## Privacy and the shared post experience

The internal and external board use the same card: author header, primary image, social actions, then the title and description. Multiple images have a carousel; its `ResizeObserver` keeps the selected photo aligned when the viewport changes. An occurrence title identical to its description is hidden from the visible caption to avoid repeating legacy derived content. The composer requires title, description, category, and location. Perceived severity is visible as selectable cards, with a separate “I cannot assess” choice; it remains distinct from the handling team's priority. Photos are optional. Structured tooltips explain categories and location without replacing visible labels and work by keyboard. The tooltip remains open while the pointer moves over its text; the trigger reports its expanded state and Esc dismisses it.

Internal posts can show the active author's display identity to the signed-in community. External identity remains opt-in: `PublicIdentity` reveals a profile link and username only for an active account with `public_profile = true`; otherwise it uses a neutral identity. Email addresses are never a display-name fallback. A verification badge does not enable a public profile on behalf of its owner.

The owner can upload or replace a PNG/JPEG profile photo in `/perfil`, up to 5 MiB. The server verifies the file signature and rejects reused blobs or signed-blob identifiers instead of accepting another person's stored file. `User.avatar` uses the existing Active Storage tables; no separate avatar table or additional migration is required. Administrators cannot replace another person's avatar through profile updates.

`GET /pessoas/:id/foto` serves a 160 × 160 JPEG with metadata stripped, after checking that the account is active and that the reader is the owner or the profile has public opt-in. It returns 404 when access is denied, including after opt-in is revoked. Responses use `Cache-Control: private, no-store`. Feed cards use this image only when the author permits a public profile; otherwise they fall back to initials or the neutral identity. Uploaded originals are never exposed by this endpoint.

`PublicationPolicy::FeedScope` is the feed contract for all readers, including administrators: only currently published, unexpired, unblocked posts with compatible source audiences appear. Internal posts require an active session; external posts require approval for their current content version. Administrative management scopes can inspect records outside the feed, without making those records visible publicly.

## Photo cover, order, and removal

The first selected photo is the cover. Authors can add files, select a cover, reorder photos, and remove existing photos within the occurrence form; existing changes take effect only when the complete form is saved. Canceling the form does not delete attachments. The file input follows the selected upload order for a new occurrence.

`Alerts::PhotoSelection` validates edits before persistence. `existing_<attachment_id>` tokens must refer to retained attachments of that alert; `new_<index>` tokens must match a submitted upload. The final order must contain each expected token exactly once, and removal IDs must be distinct attachments owned by the alert. Foreign IDs, duplicates, missing tokens, and fabricated upload positions are rejected. Existing file type/signature, size, and five-photo limits still apply.

`alerts.photo_order` is a non-null JSON array of ordered attachment IDs. `Alert#ordered_photos` and `Publication#ordered_feed_photos` provide the same cover/order to detail and feed views. An empty legacy order falls back to attachment ID order; unmapped attachments are appended deterministically. Saving edits, selection, and resulting visibility/version is transactional. Ordering alone is a content change and requires a new external approval unless the verified-author rule applies; changing photos never clears moderation restrictions.

## GPS, catalog locations, and the map

The new-occurrence form initially selects GPS, but requests device permission only after the author clicks the capture button. Capture records browser coordinates, reported accuracy, and time. A campus catalog entry is optional and may complement GPS or a map point; it is not an alternative that discards already selected coordinates. An author may instead use a catalog entry or a short descriptive manual location without GPS.

Map points use the separate `location_source = 'map'`. The author can click the map, drag its marker, use the map center, or enter latitude/longitude. Map selection clears GPS accuracy and capture time, and the model rejects those fields for any non-GPS source: it never fabricates GPS evidence. Coordinates must remain within latitude −90..90 and longitude −180..180, and remain restricted to occurrence/handling access. Clearing either map coordinate removes the marker and clears the stored selection instead of retaining an old point. Auxiliary map fields are disabled while GPS or manual mode is selected so hidden map validation cannot block those alternatives.

Leaflet 1.9.4 JavaScript, CSS, license, and supporting images are stored locally. The map lazily initializes when the map option is opened, then the browser loads OpenStreetMap tiles from `https://tile.openstreetmap.org/{z}/{x}/{y}.png`. The visible map attribution must remain visible. Opening a map sends tile requests to that external provider; GPS-only/manual use does not initialize the tile layer. Production maintainers must follow the [OSM tile usage policy](https://operations.osmfoundation.org/policies/tiles/): preserve browser referrers/caching and attribution, and do not add bulk download or offline prefetch. The default public tile service provides no uptime guarantee; GPS and manual description remain alternatives when map tiles fail. The implementation follows the [Leaflet quick-start](https://leafletjs.com/examples/quick-start/).

Google Maps import extracts coordinates from a complete HTTPS URL in the browser; it is not geocoding and makes no server request to the pasted address. Supported Google hostnames and coordinate-bearing URL forms are checked locally. A short sharing link must first be opened by its user, who then copies the expanded URL; a link without coordinates cannot be imported. The outward Google Maps link uses the documented [Maps URLs](https://developers.google.com/maps/documentation/urls/get-started) search format. This integration uses no Google API key.

## Image processing and private media

`Gemfile.lock` currently resolves `image_processing` 2.2.0 and `ruby-vips` 2.3.0. Both development and production Dockerfiles install the system libvips library. Rebuild an existing Dev Container to install changed system dependencies; `bundle install` alone cannot install libvips.

For native Debian/Ubuntu development outside the container:

```bash
sudo apt-get update
sudo apt-get install libvips
bundle install
bundle exec ruby -e 'require "vips"; puts Vips.version_string'
```

The feed endpoint is `GET /mural/:publication_id/fotos/:id`. It finds an attachment belonging to the authorized publication, rechecks access, and serves a JPEG derivative capped at 1440 × 1440 pixels, with metadata stripped. It uses `Cache-Control: private, no-store`; it does not redirect to a reusable public storage URL. Missing files and unauthorized reads return 404. Originals remain behind `GET /alertas/:alert_id/fotos/:id` with the separate alert policy. Default Active Storage routes remain disabled.

Occurrence photos accept up to five PNG/JPEG files of 5 MiB each, with server-side type/signature validation. Metadata stripping reduces accidental EXIF disclosure; it does not remove visible faces, names, or other sensitive details in the image itself. Authors must choose the audience with that limitation in mind.

These runtime dependencies follow the [ImageProcessing installation guide](https://github.com/janko/image_processing#installation) and [Rails Active Storage image transformation documentation](https://guides.rubyonrails.org/active_storage_overview.html#transforming-images). Back up attachment files and the database together. Variants do not replace original evidence or turn its URLs public.

## Updating an existing installation

1. Back up the SQLite database with its online backup API and preserve the corresponding Active Storage files. Follow the [upgrade guide](data-model-upgrade.md#1-record-the-current-state-and-back-up).
2. Install the gems and system image library. Rebuild containers when their Dockerfiles changed.
3. Run `bin/rails db:migrate`, then `bin/rails tailwindcss:build` and restart `bin/dev`.
4. Check integrity and foreign keys; review legacy occurrence posts before reauthorizing disclosure. Do not run development seeds against a shared database to install this feature.

Migration `20261003120000_unify_occurrence_publications.rb` adds descriptive locations, the verification pair, approval origin, moderation blocking, and database constraints for canonical occurrence content and approval consistency. Manual occurrence locations may be a verified catalog entry or a 3–160 character description, so an empty catalog does not require GPS.

Legacy alerts that have no `Publication` remain outside the feed. Reading their detail with GET creates nothing and discloses nothing automatically. For legacy records with an internal/public audience request, the detail displays “Registro anterior ao novo mural” and the owner must explicitly confirm the audience to create the post; an unverified public request then creates an internal post with pending external review. New code does not bulk-convert those records. This is distinct from migrating an already existing legacy occurrence publication.

For legacy occurrence publications, it preserves the previous editorial content/state in private `audit_events.metadata.legacy_editorial`, clears duplicate text columns, aligns the author with the alert, and withdraws the post with internal visibility. It preserves the post and its interactions, but does not silently expose different text/photos. News and notices retain their editorial content. Previously withdrawn occurrence posts retain a moderation block.

The migration has been applied in development and test after the local SQLite backup passed its integrity check. The local pre-change backup is `tmp/backups/development-before-social-20261003-210423.sqlite3`; it contained three accounts and no publications. This is a development-only recovery artifact ignored by Git, not a production backup policy. Rollback can restore recorded legacy snapshots, but cannot represent descriptive manual locations without a catalog ID; in that case it raises `ActiveRecord::IrreversibleMigration`. Use the [rollback limits](data-model-upgrade.md#rollback-limits) and restore a matching backup for shared-data recovery.

Migration `20261003180000_add_occurrence_photo_order_and_map_location.rb` adds `alerts.photo_order` with default `[]` and permits map points in the location-source/coordinate constraints. It has been applied in development and test after the integrity-checked local backup `tmp/backups/development-before-composer-20261003-231735.sqlite3`. Legacy attachment rows/files remain intact. Its rollback checks for map records before changing schema: if any exist, it raises `ActiveRecord::IrreversibleMigration`; use a compatible backup instead of relabeling a map point as GPS. Rolling back an empty/map-free database removes stored photo ordering.

## Main maintenance points

| Responsibility | Source |
| --- | --- |
| Canonical content and constraints | `app/models/alert.rb`, `app/models/publication.rb` |
| Initial occurrence and post transaction | `app/services/alerts/create_occurrence.rb` |
| Synchronization and approval origin | `app/services/publications/sync_occurrence.rb` |
| Author edits and administrative corrections | `app/services/alerts/update_content.rb`, `correct_content.rb` |
| Approve/reject, stale version protection | `app/services/publications/review.rb`, `app/controllers/admin/publications_controller.rb` |
| Verification and authorization | `app/services/users/change_verification.rb`, `app/policies/user_verification_policy.rb` |
| Public projection and identity | `app/presenters/publication_projection.rb`, `public_identity.rb` |
| Protected feed/profile media | `app/controllers/publication_media_controller.rb`, `profile_photos_controller.rb` |
| Profile photo ownership and upload validation | `app/models/user.rb`, `app/services/users/update_profile.rb` |
| Photo selection/order/removal and content version synchronization | `app/services/alerts/photo_selection.rb`, `update_content.rb`, `remove_photo.rb` |
| Photo selection controls | `app/javascript/controllers/photo_preview_controller.js` |
| GPS, map, and Google URL extraction | `app/javascript/controllers/geolocation_controller.js`, `app/views/shared/alerts/_location_fields.html.erb` |
| Locally packaged map resources | `vendor/javascript/leaflet.js`, `leaflet.LICENSE`, `app/assets/stylesheets/leaflet.css`, `app/assets/images/leaflet/` |
| Shared feed card and review preview | `app/views/publications/_card.html.erb`, `app/views/admin/publications/_occurrence_review.html.erb` |
| Composer and author review state | `app/views/shared/alerts/_form.html.erb`, `_publication_status.html.erb` |
| Feed styling, gallery, and accessible help | `app/assets/tailwind/social.css`, `app/javascript/controllers/post_gallery_controller.js`, `tooltip_controller.js` |

## Validation and remaining work

Confirmed results after the same-post refactor and composer/map update:

| Check | Confirmed result |
| --- | --- |
| Previous integrated RSpec suite (before the 04/10/2026 presentation/brand revision) | 681 examples, 0 failures; seed 30669; 2 min 25.8 sec (load 1.98 sec). Includes the composer, legacy-record safeguard, meeting presentation, and final map/tooltip fixes. |
| Final reported line coverage | 97.09%, 4,148 of 4,272 lines, as recorded by SimpleCov. |
| Latest confirmed RuboCop run | 311 files, no offenses. |
| Zeitwerk | Passed after the final changes. |
| JavaScript syntax | `geolocation_controller.js`, `photo_preview_controller.js`, and `tooltip_controller.js` passed. |
| Brakeman | No errors or security warnings. |
| Importmap audit | No vulnerabilities found in identified package versions; the locally vendored Preline module is skipped because it does not declare a version. This is not an audit of that module. |
| Migration regression | Real legacy-database upgrade, rollback, and descriptive-location rollback guard passed in the suite. |
| Complementary social checks after the gallery adjustment | 25 examples, 0 failures; seed 49362; 13.08 sec. Covers social browser features, social/publication requests, and the publication projection. |
| Composer contracts | 42 examples, 0 failures. |
| Composer browser checks | 8 examples, 0 failures. |
| Final map/tooltip browser checks | 3 examples, 0 failures; seed 42730. Clearing a coordinate removes the stored point, auxiliary map fields are disabled outside map mode, and hovering the tooltip text keeps it open. |
| Visual review | 13 screenshots inspected across desktop/mobile and dark/light themes; final desktop/mobile cards reviewed again after the gallery adjustment. The browser journey checks gallery alignment before each capture. |
| Development runtime | `bin/dev` restarted in Docker; server and CSS watcher active. `/`, `/entrar`, and `/mural` return HTTP 200. |
| Database/runtime dependencies | Schema `20261003180000`, SQLite integrity check `ok`, no foreign-key-check output, libvips 8.16.1. |

The social browser journey saves and restores the original window size so mobile screenshots cannot change the viewport of later administrative examples. The final full suite verifies this isolation together with the gallery resize behavior. Screenshot review does not establish a full accessibility audit. That delivery was local on `feat/alertas-crud-social`; no commit, push, merge request, or deployment was performed.

The pre-change development backup had three accounts and no publications. At the earlier same-post runtime check, development contained five accounts, one alert, and no publications, consistent with local use during implementation; it was not reset to match the backup. No real local account or alert was deleted for test cleanup. Image previews use CSP `img-src self data blob`. The subsequent map update additionally permits the OpenStreetMap tile hostname in image sources; the application scripts and Leaflet remain local.

The new service regression coverage lives in `spec/services/publications/social_occurrence_spec.rb`: immediate internal posting, pending external requests, same-post approval, rejection reason, edit/resubmission, stale reviews, verified publication/revocation, panic/private exclusion, moderation restrictions, transaction rollback, and privilege escalation prevention. HTTP regression coverage in `spec/requests/social_occurrence_request_spec.rb` exercises the same-post workflow and protected image delivery. The completed suite also includes the existing request, policy, projection, migration, and browser journey checks against the updated contract.

The composer/map update has passed the full suite, focused contracts, and browser checks above. Regression sources are `spec/services/alerts/photo_selection_spec.rb`, `spec/requests/occurrence_composer_request_spec.rb`, and `spec/features/occurrence_composer_spec.rb`. The presentation now contains genuine meeting evidence from 03/10/2026 around 18:20, with four original images and an accessible enlarged view. The dedicated meeting profile was reviewed on desktop/mobile and exported as three pages with a single gallery page; navigation/gallery tests passed 17 examples (seed 58478). The final review also checked the mobile gallery, desktop map, and printed meeting image without a focus outline. See the [presentation maintenance guide](../config/presentation/LEIAME.md#meeting-record-and-image-gallery) for its schema, source paths, and evidence limits. This record does not substitute for a retrospective, deployment, requirements approval, or formalized decisions. The presentation endpoint now returns HTTP 200, the second-delivery profile remains active, its meeting is visible, and development migrations/integrity checks passed. A previous integrated run, which predates the 04/10/2026 presentation and brand revision, recorded 681 examples and no failures; current results are in the [presentation and brand review](apresentacao-identidade-sgu-revisao.md#tests-run). The meeting and its original captures remain dated 03/10/2026; continuing validation does not change their source date.

Known limitations: email ownership confirmation remains unimplemented; the official location catalog still requires human-maintained data; photos remain optional. The social workflow does not establish a full accessibility audit or validation on physical phones. Production deployment and human validation of the academic requirements are separate activities.
