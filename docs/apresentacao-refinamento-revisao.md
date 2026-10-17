# Presentation Refinement — Review and Handoff

## Scope and published baseline

This refinement started on 04/10/2026 on `codex/refinamento-apresentacao`, from `main` commit `c95bf7cb09de2eba1fff95b2d8cd94f809703718`, the merge of [PR #13](https://github.com/lucasact4/engenharia-de-software/pull/13). That merge already published the occurrence/social implementation, SGU identity assets, and preceding presentation changes. It is evidence of source integration, not a deployment.

The [earlier identity review](apresentacao-identidade-sgu-revisao.md) is a historical handoff. Its full-suite result remains **720 examples, 1 failure**, seed **43933**. Subsequent isolated successes in that report do not turn that original run into a passing run or prove its failure unrelated. The initial refinement passed **726 examples, 0 failures**, seed **40918**. The experience/PDF phase first passed **730 examples, 0 failures**, seed **65244**; after the native appendix-link correction, the final integrated run passed **731 examples, 0 failures**, seed **65244**. Each phase and its evidence are recorded below.

## Implemented refinement — initial phase

- **Identity and theme:** existing SGU logo assets are preserved. The cover uses the horizontal logo; impact slides follow the application theme. Existing light/dark concept captures and diagram layouts remain available.
- **Titles and requirements:** optional `entrega.yml` → `exigencias[].slides[].titulo` supplies short titles consistently across slide heading, index, counter, administration, and customization. The full assignment wording remains in the information control. Stable IDs and requirement order are unchanged.
- **Technical evidence:** all currently cataloged implementation files link to the published PR #13 snapshot. Team-approval notices and checklist counts are removed. The legacy parser field `confirmado_pela_equipe` remains accepted for compatibility, without controlling presentation display.
- **Conceptual model:** the existing model, relationships, and multiplicities are preserved. The status area shows production and **Regras do modelo** for implemented rules, without a team-review badge. The physical DERs remain separate appendices.
- **Meeting gallery:** the four original 03/10/2026 captures use a featured image, thumbnail strip, navigation controls, and the existing lightbox. `evidencia_principal` selects the initial image; print includes all four originals, without a featured duplicate. Keyboard strip navigation is isolated from slide navigation.
- **Appendix navigation:** **Voltar à apresentação** restores the main slide that opened the appendix and its focus. If unavailable, it falls back to the visible conceptual slide or first available slide. In this initial phase, the return control was excluded from print; the final continuation preserves it as a visible, clickable native PDF link. Links to appendices respect the saved/temporary selection. The development active profile enables all four DER appendices; default screenshot tests disable them intentionally. Saved development selections were not reset to match test screenshots; bootstrap keys were aligned with the current catalog as described below.
- **Planning in this phase:** the milestone displays the supplied original mural captures in both themes. This phase had four priorities: requirement mapping, future local email previews with `letter_opener`, future UFRPE location seeds, and usability/bug refinement. The continuation below adds the fifth participation/UX priority. This change installs neither `letter_opener` nor official location seeds.
- **Lessons:** the existing four “Aprendi” cards accompany a crop of that column from the original retrospective board. `aprendizados_imagem` and `aprendizados_imagem_descricao` configure it. The lessons slide has no “Faltou” block; the complete board and faithful three-column transcription remain intact.
- **Evolution in this phase:** the meeting milestone linked to its slide and the two PR #13 milestones linked to the published merge. The continuation below replaces these timeline buttons with chronological cards; source references remain internal.

The default second-delivery order remains `capa`, `conceito-visual`, `funcionalidades`, `retrospectiva`, `modelo-conceitual`, `reunioes`, `evolucao`, `proximos-passos`, `status-report`, `encerramento`. The first-delivery profile and saved selection keys remain compatible. No team-approval step is required to present implemented content.

## Bootstrap and map repair

The first full run of this refinement recorded **726 examples, 3 failures**, seed **30750**. Two failures exposed profile seeds referring to removed catalog content keys; the third exposed a genuinely missing local Leaflet asset inherited from the published baseline. These were corrected rather than attributed to unrelated tests.

[`db/seeds/presentation_profiles.rb`](../db/seeds/presentation_profiles.rb) now lists valid current content keys. It still creates only missing named profiles and preserves saved selections. This is a bootstrap compatibility correction, not a reset of the active profile or its four DER appendices.

The existing local Importmap pin required `leaflet.js`, but the file was absent. Leaflet **1.9.4** JavaScript, source map, and BSD 2-Clause license have been restored under `vendor/javascript/`. The files came from the official documented distribution on unpkg, referenced by [Leaflet downloads](https://leafletjs.com/download.html). The restored JavaScript SHA-256, encoded as base64, matches the documented integrity hash exactly:

```text
20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=
```

The Importmap remains local; this does not introduce a runtime CDN dependency or change the existing map/tile-provider rules. Keep the accompanying copyright/license notices. The focused profile/composer check passed **15 examples, 0 failures**, seed **38293**. The subsequent full integrated run passed **726 examples, 0 failures**, seed **40918**, including those repaired paths.

## Main implementation references

- [`entrega.yml`](../config/presentation/entrega.yml), [`funcionalidades.yml`](../config/presentation/funcionalidades.yml), [`diagramas.yml`](../config/presentation/diagramas.yml): requirement wording, titles, published file evidence, model rules.
- [`gestao.yml`](../config/presentation/gestao.yml), [`_meeting_gallery.html.erb`](../app/views/presentations/shared/_meeting_gallery.html.erb), [`meeting_gallery_controller.js`](../app/javascript/controllers/meeting_gallery_controller.js): real meeting record and screen/print gallery.
- [`retrospectiva.yml`](../config/presentation/retrospectiva.yml), [`retrospective.rb`](../app/models/presentation/retrospective.rb), [`_status_report.html.erb`](../app/views/presentations/slides/_status_report.html.erb): source board, lessons crop, and lesson cards.
- [`planejamento.yml`](../config/presentation/planejamento.yml), [`evolucao.yml`](../config/presentation/evolucao.yml): mural evidence, future work, and published milestones.
- [`presentation_controller.js`](../app/javascript/controllers/presentation_controller.js), [`show.html.erb`](../app/views/presentations/show.html.erb), [`_heading.html.erb`](../app/views/presentations/shared/_heading.html.erb): appendix return and centralized titles.
- [`LEIAME.md`](../config/presentation/LEIAME.md): maintenance, profiles, evidence fields, commands, and PDF export.
- [`leaflet.js`](../vendor/javascript/leaflet.js), [`leaflet.js.map`](../vendor/javascript/leaflet.js.map), [`leaflet.LICENSE`](../vendor/javascript/leaflet.LICENSE): restored local Leaflet 1.9.4 distribution and its required notices.

## Previous validation — initial refinement

Confirmed results before the experience/PDF continuation below:

- RSpec: **726 examples, 0 failures**, seed **40918**, **3 min 30.1 sec**. Line coverage: **97.35%** (**4,274/4,390**). This integrated run includes presentation, social security/media, occurrence composer, administration/registration, and model specs. The log is `/tmp/sgu-refinement-verified.log` inside the development container.
- RuboCop: **319 files, no offenses**.
- Zeitwerk: passed.
- Brakeman: no warnings.
- Tailwind build: passed.
- JavaScript syntax: `node --check` passed for `meeting_gallery_controller.js`, `presentation_controller.js`, and the restored `leaflet.js`.
- `git diff --check`: clean.
- Visual review: **20 captures**, ten main slides in each theme, fit the **1920×1080** presenting-mode viewport. The mobile gallery was reviewed at **390 px** width.
- PDF: `tmp/apresentacao/sgu-refinamento.pdf`, exported from the actual development active profile, has **14 pages: ten main slides plus four DER appendices**. All 14 pages were rendered and reviewed, with no overflow or blank page; the meeting page includes all four original captures. This count applies to that profile, not every customization.
- Asset preservation: SHA-256 hashes of the three newly supplied source assets remain unchanged. The “Aprendi” display uses the crop supplied by the user unchanged; its complete original board also remains preserved. No supplied image was cropped or edited during this refinement.

Presentation coverage includes [`presentation_revision_request_spec.rb`](../spec/requests/presentation_revision_request_spec.rb), [`presentation_revision_spec.rb`](../spec/features/presentation_revision_spec.rb), and [`presentation_meeting_spec.rb`](../spec/features/presentation_meeting_spec.rb). These specs passed in the final integrated run. The earlier failed runs retain their own dated results; they are not relabeled as passing runs.

The presentation export and capture commands remain the existing scripts documented in the maintenance guide. No database migration was created or run. No commit, push, gem installation, account data conversion, or deployment was performed during this refinement; restoring the already-pinned Leaflet distribution repairs a missing vendored resource.

## Evidence gaps at the initial refinement

- The GitHub repository screenshot was absent in the initial phase and has since been supplied unchanged in the continuation below. Optional code screenshots remain absent; published source links already provide usable evidence.
- Leadership reports the use-case diagram complete, but its image and version/origin/date are absent from `diagramas.yml`. Attaching that artifact is necessary to display it; no team-approval gate is introduced.
- The separate occurrence-flow artifact is not attached. The complete retrospective date is not proven, and actions with owners/deadlines are not recorded. The 03/10 meeting does not supply those missing facts.
- Requirement identifiers still need mapping to the implemented journeys. The card #11 URL and staging URL remain empty; no staging deployment is recorded.
- Local email preview and official location seeds are future priorities. Email confirmation is not implemented by this refinement. Actual presentation duration and external-link access require a timed rehearsal and access check.

Meeting images remain dated **03/10/2026**, around **18:20**; the captured times do not establish duration. Renewed visual-concept captures and this refinement are dated **04/10/2026**. Mural screenshots demonstrate application behavior without establishing a public deployment.


## 04/10/2026 continuation — theme, timing, sharing, and linked PDFs

This continuation keeps the same application/profile architecture and stable slide order. It adds a softer sage **presentation-only** light theme, usable time controls, public QR access, a supplied GitHub screenshot, and themed PDFs with preserved links. The 726-example result above is a previous validation; it does not substitute for the current integrated run. No commit, push, deployment, or database migration was performed for this continuation.

### Final behavior and sources

- [`experience.css`](../app/assets/stylesheets/presentation/experience.css) scopes the sage light palette to the presentation and preserves the selected theme in print: colors, logos, and light/dark screen captures. It also styles the timeline, timer, sharing, and responsive index.
- [`presentation_timer_controller.js`](../app/javascript/controllers/presentation_timer_controller.js) and [`_timer.html.erb`](../app/views/presentations/shared/_timer.html.erb) start paused at **seven minutes**. Start, pause, reset, and editing **1–120 whole minutes** are available. Applying a new duration resets and pauses; no automatic start occurs. A real deadline based on `Date.now()` prevents delayed intervals in background tabs from slowing the countdown. Public index/customization omit per-slide times and summed estimates; internal timing metadata remains compatible.
- [`_share_code.html.erb`](../app/views/presentations/shared/_share_code.html.erb) uses `entrega.yml` → `links.apresentacao` and `links.qr_code`. The local QR PNG encodes the exact configured public ngrok address, including `/apresentacao#s-capa`. This tunnel is public access to the presentation, not a production deployment.
- [`gerar_qr_apresentacao.py`](../script/gerar_qr_apresentacao.py) takes `URL [--output arquivo.png]`. Update the public URL in `entrega.yml` and regenerate the PNG together whenever the address changes. Python, `qrcode`, and Pillow are generator requirements only; `qrcode` and `zxing-cpp` under `tmp/qa_dependencies` were QA tools, not Rails dependencies. Regeneration reproduces the checked PNG byte for byte.
- [`repositorio.png`](../app/assets/images/presentation/github/repositorio.png) is the supplied GitHub screenshot, preserved byte for byte. SHA-256: `8c5484161a039afdf400fd482655dc7107c7c797c88b4555ca0d588283549c69`. The former missing-repository-capture item is resolved; optional individual code captures remain absent.
- [`evolucao.yml`](../config/presentation/evolucao.yml) supplies **eleven chronological milestones**: landing 14/09, first delivery 23/09, use cases **≈30/09**, initial web presentation 01/10, data/migration and conceptual model 02/10, operation and meeting 03/10, retrospective/planning, brand, and revised presentation 04/10. The use-case date has `estimada: true` and an explicit note that the actual update date is unknown; it is not a verified commit date or fabricated artifact. Source commits stay internal rather than appearing as timeline buttons. The 04/10 retrospective/planning milestone does not establish the date of the original retrospective session.
- [`planejamento.yml`](../config/presentation/planejamento.yml) now has a fifth future priority: simplify publishing/following and use persuasive design inspired by Instagram to encourage campus participation. This describes intended UX work; likes alone do not mean a gamification system exists. `letter_opener`, official location seeds, and email confirmation remain future work.
- [`exportar_apresentacao_pdf.rb`](../script/exportar_apresentacao_pdf.rb) accepts `APRESENTACAO_TEMA=dark` (default) or `light`. The PDF keeps the chosen theme and capture variants. `presentation_public_asset_url` in [`presentations_helper.rb`](../app/helpers/presentations_helper.rb) makes image links use the configured public host; code links and internal appendix return links remain clickable. The exporter may fetch Rails through its container address, while PDF image links use the public address.

### Current validation — experience/PDF and native appendix links

| Check | Confirmed result |
| --- | --- |
| Integrated RSpec | **731 examples, 0 failures**, seed **65244**, **4 min 24.5 sec**, after the native appendix-link correction. |
| Line coverage | **97.15%**, **4,270/4,395** lines. |
| Test log | `tmp/qa_final_verified.log` in the project. |
| RuboCop | **319 files, no offenses**; the two Ruby test files changed by the final appendix fix also passed a focused check without offenses. |
| Zeitwerk / Brakeman | Zeitwerk passed; Brakeman no warnings. |
| Asset checks | Tailwind build, JavaScript syntax, and `git diff --check` passed. |
| Desktop visual review | **20 captures**: all ten main slides at 1920×1080 in both themes. |
| Responsive review | All ten main slides at **320×568**, **390×844**, **768×1024**, and **1366×768**, in both themes, without horizontal overflow. |
| PDF review | Both exports have **14 pages**, **31 public HTTP(S) links**, and **nine valid internal destinations** each; all **28 pages** rendered and reviewed. |
| QR verification | Exact configured URL decoded from the PNG and from the cover raster of both themed PDFs. |

The complete exports are `tmp/apresentacao/sgu-atual-escuro.pdf` and `tmp/apresentacao/sgu-atual-claro.pdf`, each ten main slides plus four selected DER appendices. The PDFs contain no localhost or `rails-app` links. This page count reflects the actual selected development profile and changes with selection. Timers/dialogs/navigation controls are omitted from print, and the meeting still prints all four originals.

Three existing assertions were adapted to the intentional removal of public estimates, presentation-specific color, and public image-link target/rel behavior; their focused check passed **3 examples, 0 failures** before the final integrated run. Previous failed runs and the historical 720/1 report retain their original results.

Remaining evidence/operational gaps are the unattached use-case and occurrence-flow artifacts, requirement mapping, retrospective session date/recorded actions, optional code screenshots, and actual deployment/email/location work. The approximate use-case timeline entry does not resolve the missing artifact. Changing or stopping the tunnel can break public presentation/image links; update the configuration, regenerate/decode the QR, and recheck external access and PDF links before presenting.


### Native appendix return compatibility

The subsequent appendix fix makes **Voltar à apresentação** safe both as a native link and as JavaScript navigation. Server rendering chooses the visible conceptual-model slide, or the first visible main slide when the conceptual model is absent. JavaScript updates each link's actual `href` to the last visible main origin; if that origin is no longer visible, the fallback remains the visible conceptual model or first available main slide. The final PDF keeps this return link visible and clickable, with the resolved native destination. PDF export therefore has a valid internal destination for first-delivery profiles and temporary selections that hide the conceptual model as well as the default second delivery.

The targeted request/browser verification passed **two examples, zero failures**. The full integrated rerun after this fix passed **731 examples, zero failures**, seed **65244**, in **4 min 24.5 sec**, with **97.15%** line coverage (4,270/4,395); log: `tmp/qa_final_verified.log`. The preceding **730/0** and **726/0** runs retain their original scope. The final changed Ruby tests passed RuboCop, and JavaScript syntax plus `git diff --check` remained clean. The initial four planning priorities and timeline commit buttons described above belong to the earlier phase; the final configuration has **five priorities** and **no timeline source buttons**.
