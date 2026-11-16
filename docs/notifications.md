# Notifications and delivery

SGU stores a separate inbox for each recipient. The bell appears in the authenticated portal and administration layouts. Hover over it for a short preview, or click it and use the keyboard to keep the preview open. The full inbox is at `/notificacoes`.

## Events and recipients

Only active, approved accounts receive new notifications.

| Event | Recipients |
| --- | --- |
| An operational alert changes status | The alert's author, except for anonymous occurrences |
| A publication changes publication or review status | The publication's author, except for anonymous occurrences |
| A new comment or reply | The publication's author and, for a reply, the parent comment's author. The commenter is excluded and recipients are deduplicated |
| A publication or comment receives a like | The author of that publication or comment, excluding self-likes |
| An open occurrence is published nearby | Other eligible readers who chose a nearby catalog location |
| A panic alert is created | Administrators and accounts with the active `security` role |
| A content report is created or reopened | Administrators |
| A publication enters pending review, including a changed content version awaiting review | Administrators |

Authors who publish anonymously are excluded from notifications about their own anonymous occurrence, including its status, comments, and likes. Authorized administrators can still receive moderation notices for the occurrence. Administration is granted by `users.admin`. Administrators and security accounts retain the same author and social notification behavior as other accounts.

## Persistence, permissions, and duplicate prevention

`Notification` belongs to its recipient and references the relevant alert, publication, comment, or content report. Model callbacks invoke `Notifications::Events` inside the originating database transaction. If the action rolls back, its notifications and external delivery records roll back too. A notification persistence failure also fails the originating transaction. The inbox can be read independently of the external delivery worker.

The database enforces uniqueness of `(user_id, event_key)`. Event keys distinguish status transitions and review events. Content reports use a persisted `notification_version`, advanced before saving a new report or a state change, so separate reopenings remain distinct even when timestamps are identical. Panic retries using the existing alert creation idempotency mechanism reuse the same alert and inbox event. Like keys identify the person and target: removing and adding the same like does not send another notification. Different comments and later status transitions remain separate events.

Recipients are selected when the event occurs. Migration does not backfill historical events, and granting a role later does not distribute earlier events to new recipients. Writes that bypass Active Record callbacks, such as direct SQL or `update_all`, do not generate notifications.

Every inbox query is restricted to the signed-in recipient. `Notification.visible_to` also checks current account status, feed visibility, hidden comments, operational alert access, and administrative/security permissions. Revoking a role or restricting a publication hides the affected notifications without deleting their persisted history. The notification link does not grant access: destination controllers continue to enforce their own policies. JSON inbox responses use `Cache-Control: no-store, private`.

## Reading and panic priority

New records have a null `read_at`. Opening the preview, reading the inbox page, or following a link does not automatically mark them as read. Use **Marcar como lida** for a single ordinary notification, or the inbox's bulk read action for ordinary notifications. Repeating a read request preserves the first recorded reading time.

Unread panic notifications are sorted ahead of ordinary notifications and appear in a highlighted popup. Acknowledged panic notifications return to normal chronological ordering, so older events do not crowd out new social notifications. The popup shows one unread panic event at a time, starting with the oldest. Use **Reconhecer alerta** to record that recipient's reading and reveal the next unread panic event. Bulk reading deliberately excludes panic notifications. Recognition does not assign a responder, change the alert status, or confirm that help is on the way. Other recipients keep their own unread state.

The popup has alert-dialog semantics and live announcements. It does not take keyboard focus away from ongoing work. The preview supports clicking, keyboard activation, and Escape; the full inbox and ordinary form submissions remain available without JavaScript.

## Delivery preferences and nearby occurrences

Open **Preferências de entrega** at `/notificacoes` to opt in to email, enable push on the current browser, or choose a catalog location. Email and push apply to operational status changes (`alert_status`), publication or review status changes (`publication_status`), and nearby occurrences (`nearby_alert`). Social, moderation, and urgent panic notices stay in the SGU interface.

Nearby alerts use a radius of 500 metres around the reference coordinates of the selected active catalog location. The occurrence needs an open status, current feed visibility for the recipient, and a usable point. The point comes from coordinates that the occurrence author agreed to share or from its active catalog location. Readers choose a reference location without sharing their device location. The occurrence author is excluded, and each eligible reader receives at most one nearby notice per occurrence publication. Choose **Desativar alertas próximos** to remove the location preference.

Email and browser push use generic text and direct recipients to the authenticated inbox for details. The subscription is bound to the signed-in session and deleted on sign-out or session removal. Use **Desativar push neste navegador** to turn it off directly. Browser push requires a compatible browser, permission, and a secure context such as `http://localhost` in development or HTTPS in production.

SGU exposes `/manifest.json` and `/service-worker.js` publicly, and both authenticated layouts link the manifest. On iOS and iPadOS, add SGU to the Home Screen and open the installed web app before enabling push, where supported by the device and browser. [WebKit's browser support guidance](https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/).

## Delivery and operational limits

While an authenticated page is visible, the Stimulus controller queries the inbox every three seconds and immediately when the page regains visibility. The preview contains ten records. The full inbox paginates fifty records per page. Network requests time out after eight seconds. Inbox updates retry on later polls, and users can retry reading requests. Reloading or signing in again retrieves unread events, including panic alerts. Turbo clears private preview and popup content before caching, and back navigation repopulates it from the server. The full inbox opts out of Turbo snapshots.

The durable delivery outbox records one email per notification and one push per browser subscription. Solid Queue runs `DeliverNotificationsJob` every fifteen seconds in development and production. The job checks current recipient access, anonymity, preferences, nearby eligibility, and subscription validity before contacting a provider. It claims due deliveries atomically and retries transient failures with increasing delays for up to five attempts. An interrupted claim becomes available again after five minutes. If a provider accepts an alert just before the worker stops, a retry can reach that provider again. Browser push uses a stable tag for the same notification.

Panic popups require a visible authenticated SGU page. Their three-second polling interval does not guarantee a response time, and acknowledging the popup records only that recipient's reading.

## Setup and validation

Use the existing project Ruby/Bundler environment or Dev Container. Install dependencies, prepare the primary and queue databases, and build CSS before starting the application.

```bash
bundle install
bin/rails db:prepare
bin/rails tailwindcss:build
bin/dev
```

`bin/dev` starts the web server, CSS watcher, and Solid Queue worker. In an environment that starts those processes separately, run `bin/jobs` with the same Rails environment and delivery settings as the web server. The migrations `db/migrate/20261106120000_create_notifications.rb` and `db/migrate/20261107120000_add_notification_delivery.rb` add the inbox, preferences, subscriptions, outbox, and the report notification sequence. `db:prepare` creates missing databases and applies pending migrations. When it initializes a database, it also runs the existing seeds. Development seeds create or reset the two standard demo accounts, including their passwords, administrator flag, and active status.

Development uses file mail unless SMTP is configured. For SMTP delivery, set `SGU_SMTP_ADDRESS` to the SMTP hostname, `SGU_SMTP_PORT` if it differs from `587`, and `SGU_SMTP_USERNAME` and `SGU_SMTP_PASSWORD` when the server requires authentication. Set `SGU_NOTIFICATION_FROM` to the sender address accepted by the provider. Production email requires `SGU_SMTP_ADDRESS` and `SGU_NOTIFICATION_FROM`. Configure `APP_HOST` to the production hostname used in inbox links.

For browser push, set `SGU_VAPID_PUBLIC_KEY`, `SGU_VAPID_PRIVATE_KEY`, and `SGU_VAPID_SUBJECT`. The subject identifies an operator contact, for example `mailto:admin@example.org`. Generate a key pair once with `WebPush.generate_key`. The following example writes the keys to a new file without printing their values. Set `SGU_VAPID_KEY_FILE` to an absolute path outside the repository in a private directory before running it.

```bash
bin/rails runner '
  key = WebPush.generate_key
  File.open(ENV.fetch("SGU_VAPID_KEY_FILE"), File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
    file.puts "SGU_VAPID_PUBLIC_KEY=#{key.public_key}", "SGU_VAPID_PRIVATE_KEY=#{key.private_key}"
  end
'
```

Store the private key and SMTP password in the deployment's secret store and supply them to both the web and worker processes. Keep secret values out of source control and logs.

Run the focused checks with the existing isolated test database:

```bash
RAILS_ENV=test bin/rails db:prepare
bin/rails tailwindcss:build
bundle exec rspec spec/services/notifications/events_spec.rb spec/requests/notifications_request_spec.rb
bundle exec rspec spec/requests/rf014_delivery_spec.rb
bundle exec rspec spec/features/notifications_spec.rb
```

The feature checks require Selenium/Chrome, configured as described in [Local development](development.md) and the README. Test commands above are the intended verification entry points; consult the implementation's test report for executed results.

The main integration points are `app/services/notifications/events.rb`, `app/models/notification.rb`, `app/policies/notification_policy.rb`, `app/controllers/notifications_controller.rb`, and `app/javascript/controllers/notifications_controller.js`. Keep event creation transactional and extend both current-access filtering and role tests when adding notification kinds.
