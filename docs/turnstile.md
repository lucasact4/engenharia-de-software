# Turnstile and Concealed-Author Occurrences (RF005)

## Current MVP scope

Submitting an occurrence requires an active signed-in account. For the current RF005 work associated with Trello card #28, the chosen implementation conceals the account's identity from ordinary mural readers; it does not introduce a guest-submission endpoint or an untraceable report. Accountless submission remains deferred and requires an explicit later scope decision. This records the implementation choice for this task, not institutional approval of the requirements conflict.

`anonymous_public` conceals attribution in both internal and external mural audiences, including the internal post awaiting external review. A public-profile opt-in or verification badge does not override that choice. Ordinary readers receive no author account ID, profile link, username, avatar, or verification badge. The author and operational handlers may still identify the responsible account when `AlertPolicy` permits it. Concealment does not redact identifying text or faces that the author includes in the report itself.

RF016 submission metadata remains retained: the IP address and User-Agent are encrypted, and the submission timestamp is stored with the occurrence's protected audit. These fields are available through the authorized administrative detail, never through mural or map data. Operational access to the responsible account does not by itself grant access to this administrative audit.

## Configure the widget

The concealed-author option is enabled only when both variables are configured:

- `TURNSTILE_SITE_KEY`: the public key rendered in the form.
- `TURNSTILE_SECRET_KEY`: the secret used only by the server for Cloudflare Siteverify.

Use separate widgets for development, staging, and production. In the Cloudflare dashboard, restrict the production widget to the project's domains. Keep the secret out of JavaScript, Git, and logs. The Turnstile token is not logged. The Cloudflare request validates the token without sending the stored RF016 audit metadata.

Without both keys, ordinary authenticated submission remains available and the concealed-author checkbox is disabled. The server also rejects forged concealed-author submissions when protection is unconfigured.

## Form and server contract

The form submits the standard `cf-turnstile-response` field. There is no `cf_turnstile_response` alias. `AlertsController` passes that token to `TurnstileVerifier`, which requires Siteverify success, action `anonymous_occurrence`, and a hostname matching the request host.

Missing, invalid, expired, or incorrectly bound tokens fail closed. Unconfigured protection, provider errors, invalid responses, and network timeouts also fail closed. The occurrence form returns HTTP 422 instead of creating the concealed-author post. CAPTCHA verification does not replace the active-account requirement or moderation policy.

Creator search follows the identity visible to the requester: the displayed name or a publicly exposed username. It must not match hidden business names, usernames or private-profile identifiers that are not displayed to that reader, or a concealed author's real identity for ordinary readers. Existing author and operational access remains governed by the alert policy. See [the occurrence workflow](occurrence-social-flow.md#rf005-authenticated-submission-and-concealed-attribution).

## Regression coverage

The browser regression exercises the actual form and standard response-field submission with a simulated Turnstile provider. It does not solve a live CAPTCHA or establish that deployment keys and allowed hostnames are configured correctly. Request and verifier coverage separately checks rejection and server-side validation. Verify the real widget configuration for each environment before relying on it.
