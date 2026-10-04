# Presentation and SGU Brand Revision — Review and Handoff

Revision of 04/10/2026 on the local branch `feat/alertas-crud-social`. This document lets another reviewer check the work without the original conversation. Nothing was committed, pushed, merged, or deployed. The [presentation maintenance guide](../config/presentation/LEIAME.md) describes the configuration formats in detail; this document records what changed and how it was validated.

## Previous state

- **Layout:** at 1920×1080 in presenting mode with the second-delivery deck, `funcionalidades` overflowed (1026 px of content for 964 px available) and `modelo-conceitual` overflowed heavily (1680 px for 964 px).
- **Retrospective:** the image was missing, so the slide showed a pending notice.
- **Visual concept:** the captures were dark-only and showed the old template mark (a map-pin tile). The phone capture was cropped by `object-fit: cover`.
- **Contrast:** on dark slides the requirement badge was nearly invisible in the dark theme, because `--apr-g-100` remaps to a dark surface.
- **GitHub slide:** paths, tests, and criteria were always listed on the slide.
- **Brand:** the application still showed generic map-pin tiles. `public/icon.svg` and the favicon were the default Rails red circle, and the PWA manifest was named "RailsBase".
- **README:** it described the "Rails Base" template from Propósito Digital.

## Strategy

- Keep every slide ID and the second-delivery order: `capa`, `conceito-visual`, `funcionalidades`, `retrospectiva`, `modelo-conceitual`, `reunioes`, `evolucao`, `proximos-passos`, `status-report`, `encerramento`.
- Move secondary detail into dialogs and information buttons, so each main slide fits 1920×1080 without hiding evidence. Print keeps a compact version.
- Use only real evidence. Record nothing that cannot be proven, such as the retrospective date or agreed actions.
- Create one project-owned SGU mark and apply it through a single helper.

## Changes per slide

| Slide | Change |
| --- | --- |
| `capa`, `encerramento` | SGU symbol and horizontal logo with `tone: :dark_surface`: the negative version on screen, the standard version in print. The presentation top bar uses the symbol. |
| `conceito-visual` | Light and dark captures switch with the system theme (`sgu.theme` / `data-theme`). The lightbox shows the version of the active theme; print shows the light one. Added a 6-color palette from `theme.css`, a brand card (new key `conceito-visual.marca`), and a "Tema exibido" indicator. Capture notes moved to an information button (Popover API), with a one-line summary in print. The phone capture is no longer cropped. Team validation is still pending. |
| `funcionalidades` | Keeps the two configured journeys: "Registrar ocorrência e acompanhar o atendimento" and "Publicar e interagir no mural". Each journey shows a summary, a 3-step mini flow, its state with "aceite da equipe pendente", and a "Ver implementação" dialog. Each dialog lists 6 files (controllers, model, service, view, policy) and the tests. Files present in published commit `658bfde` get GitHub permalinks; the others are labelled local. Other additions: a GitHub capture slot (placeholder until `repositorio.captura` is set), "Abrir repositório", an "Estrutura" dialog (folder counts, CI jobs), and a "Critérios de “completa”" dialog (key `criterios` kept). An extras strip (new key `extras`) lists Pânico (partial), Aprovação pública, Selo de verificado, Moderação (implemented), and Cadastro e perfis (partial; email confirmation not implemented). Notes appear in popovers and are printed for partial items. Print shows compact file basenames of code and tests. |
| `retrospectiva` | Real board image in a neutral frame, zoomable through the existing lightbox, with a legend that includes counts. It has an "Abrir retrospectiva" button (new tab, `noopener noreferrer`) and the visible URL, which is clickable in the PDF. No iframe. The date is not recorded, because it is not known. |
| `modelo-conceitual` | Same 11 concepts and 20 relations, re-laid out at 1350×580. The "Dimensões distintas" box moved into `notes`, which are shown under "Relações e cardinalidades". Ports are distributed along each side, and multiplicities are drawn at both ends. "Ampliar" overlays the corner, and the footer was compacted into badges and information buttons. In presenting mode, the canvas font is limited by the viewport height. Multiplicities were checked against the models (`belongs_to` optional/required, `has_one :publication`, `Alert::MAX_PHOTOS = 5`); none changed. The physical DER appendices are unchanged. |
| `evolucao` | Five milestones after 23/09/2026, listed below. |
| `proximos-passos` | Four priorities with dependencies. No dates or owners. |
| `status-report` | The four "Aprendi" cards are shown as lessons. The four "Faltou" titles are shown as points to improve, explicitly "ainda sem ações, responsáveis ou prazos". Adds a thumbnail, the session link, and an internal link to the board slide. |
| `reunioes` | Unchanged (meeting of 03/10/2026, around 18:20). |

The `evolucao` milestones:

- 27/09: `da70a47` (published).
- 02/10: `658bfde`, PRs #11 and #12 (published).
- 03/10: alignment meeting, around 18:20.
- 03–04/10: occurrences, handling, and board. Local commits `6c67d98..c965095` are on `feat/alertas-crud-social` but not on `origin`; there are also uncommitted changes.
- 04/10: this revision (local).

The use-case diagram review has no evidence in the repository, so it is not marked as done. The root file `mermaid-diagram.png` is an unrelated landing-pages diagram from another project.

Two changes apply to all slides: the requirement badge on dark slides now has enough contrast, and below 640 px the top bar shows only the symbol.

## Main files changed

- **Models and helpers:**
  - `app/models/presentation.rb`
  - `app/models/presentation/retrospective.rb` (new)
  - `app/models/presentation_diagram.rb`
  - `app/helpers/presentations_helper.rb` (`presentation_asset?`)
  - `app/helpers/brand_helper.rb` (new)
- **Views:**
  - `app/views/presentations/` slides and shared partials
  - new partials `_dialog`, `_dialog_button`, `_info`, and `_evidence_dialog` in `app/views/presentations/shared/`
  - `_figure` now has theme variants
  - the unused `_pin_icon` partial was removed
- **JavaScript:** `app/javascript/controllers/presentation_controller.js`
  - zoom follows the active theme
  - `openDialog`, `closeDialog`, and `dialogClosed`
  - `dialogOpen()` is true while any dialog is open
  - popovers close when the slide changes
- **CSS:**
  - `app/assets/stylesheets/presentation/evidence.css` and `retrospective.css` (new)
  - edits in `base`, `deck`, `slides`, `content`, `delivery`, `diagrams`, `print`, `responsive`, `adjustments`, and `theme` under `app/assets/stylesheets/presentation/`
  - brand rules in `app/assets/stylesheets/theme.css`
  - the `.admin-sidebar-header` rule in `app/assets/tailwind/admin.css`
- **Content:** YAML files in `config/presentation/`
- **Scripts:** `script/gerar_marca_sgu.rb` and `script/capturar_conceito_visual.rb` (new)
- **Documentation:** `README.md` and `config/presentation/LEIAME.md`

## Evidence configuration

`config/presentation/funcionalidades.yml` holds an explicit evidence catalog. Each entry has `tipo`, `caminho`, `papel`, `publicado`, and an optional `captura`.

- Paths must be relative paths under `app|config|db|lib|spec`, with no `..`.
- `publicado: true` means the file exists in `publicacao.commit` (`658bfde07f9fb7f619768538a1c8648e669c0204`), and the dialog links to `/blob/<sha>/<path>`.
- `publicado: false` is shown as "Somente na cópia local".
- The server never reads files from URL parameters.
- `spec/models/presentation_spec.rb` checks every flag against Git when the commit exists locally.

When new code reaches `main`, update the commit and the flags. See [Functionalities and code evidence](../config/presentation/LEIAME.md#functionalities-and-code-evidence).

## Brand files and editable source

All brand files are in `app/assets/images/brand/`:

| File | Content | PNG size |
| --- | --- | --- |
| `sgu-simbolo.png` | Symbol only | 931×1024 |
| `sgu-logo-horizontal.png` | Symbol with "SGU" beside it | 1189×512 |
| `sgu-logo-vertical.png` | Symbol with "SGU" below it | 674×1024 |

- Each file has a `-negativo` variant for dark backgrounds and an SVG source.
- `sgu-marca-fonte.svg` is the editable artboard.
- The PNGs have 4 bands and transparent corners and edges, with no background baked in.

`bundle exec ruby script/gerar_marca_sgu.rb` regenerates all of them. It also writes `public/icon.png`, `public/icon-maskable.png`, `public/icon.svg`, and `app/assets/images/favicon.png`.

**Design:**

- The shield stands for the academic setting.
- The sprout over a field stands for campus, rural life, and community.
- The gold seed stands for knowledge. The gold is the existing accent `#F2BD57`, which echoes the torches of the reference without copying the UFRPE coat of arms.
- The greens are `#153C36`, `#226A5C`, and `#2F8A76`.
- The SGU mark is the project's own. It is not the official UFRPE coat of arms.

**Where the brand is used:**

- `sgu_brand(layout, tone:)` in `app/helpers/brand_helper.rb` renders it, with CSS in `app/assets/stylesheets/theme.css`.
- Landing header and footer.
- Auth shell: login, registration, and passwords.
- Portal header: the symbol on mobile, the horizontal logo from the `sm` breakpoint up.
- Admin sidebar: the horizontal logo when expanded and the symbol when collapsed.
- Presentation bar, cover, and closing slide.
- Favicons.
- `app/views/pwa/manifest.json.erb`. That template exists, but no route serves it at the moment.

**Left unchanged:**

- The mailer layout, which has no brand usage.
- Docker services, volumes, the `rails_base:*` tasks, `lib/tasks/proposito.rake`, and `LICENSE`.
- Old assets that are no longer used were kept, not deleted: `app/assets/images/presentation/entrar-mobile.png`, `app/assets/images/logo-proposito.png`, `logo-slogan.png`, and `logo-white.png`.

## Fonts and licenses

The "SGU" lettering is drawn as custom geometric strokes in `script/gerar_marca_sgu.rb`. No external font is embedded, so no font license applies. Leaflet keeps its license file at `vendor/javascript/leaflet.LICENSE`, and the project `LICENSE` is unchanged.

## How to add the GitHub capture

1. Take a manual screenshot of the repository page on GitHub.
2. Save it as `app/assets/images/presentation/github/repositorio.png`. The `github/` folder does not exist yet.
3. Set `repositorio.captura: "presentation/github/repositorio.png"` in `config/presentation/funcionalidades.yml`.

Until then, the slide shows a discreet placeholder.

## How to add controller, model, or view captures

1. Save the PNG in the same folder, for example `app/assets/images/presentation/github/alerts-controller.png`.
2. Set `captura` on the matching evidence entry in `funcionalidades.yml`.

The capture appears inside that journey's "Ver implementação" dialog.

## How to regenerate the light and dark captures

1. In a separate Dev Container terminal, start a second server that Selenium can reach:

   ```bash
   RAILS_DEVELOPMENT_HOSTS=rails-app bin/rails server -b 0.0.0.0 -p 3100 -P tmp/pids/apresentacao-3100.pid
   ```

2. Run the capture script. The output folder is optional and defaults to `tmp/conceito_visual/`.

   ```bash
   bundle exec ruby script/capturar_conceito_visual.rb [output dir]
   ```

3. Review the images, then copy them to `app/assets/images/presentation/`. Dark files keep their names (`landing-desktop.png`, `landing-completa.png`, `landing-mobile.png`, `entrar-desktop.png`); light files add `-claro`.
4. Update `capturado_em` in `config/presentation/conceito_visual.yml`.

Details: [Visual concept captures](../config/presentation/LEIAME.md#visual-concept-captures).

## How to verify and export the PDF

1. Run `bin/rails tailwindcss:build`, or restart `bin/dev`.
2. Start the port-3100 server shown above.
3. Run:

   ```bash
   bundle exec ruby script/exportar_apresentacao_pdf.rb
   ```

   The output is `tmp/apresentacao/sgu-segunda-entrega.pdf`.
4. Inspect every page: one slide per A4-landscape page, no dialogs or buttons, readable diagrams, and clickable links.

Details: [Run and export PDF](../config/presentation/LEIAME.md#run-and-export-pdf).

## Tests run

The coordinator ran these on 04/10/2026.

| Command or scope | Result |
| --- | --- |
| `bundle exec rspec` (full suite) | 720 examples, **1 failure**, seed 43933, line coverage 97.15% (4263/4388) |
| `spec/features/admin/users_features_spec.rb` re-runs | 8 runs: the first 2 failed, the next 6 passed (including seed 43933) |
| `spec/features/admin spec/requests/admin spec/requests/presentation_revision_request_spec.rb` (after the final sidebar change) | 95 examples, 0 failures |
| Presentation model, helper, and request specs (including retrospective and brand helper) | 91 examples, 0 failures |
| `spec/requests/presentation_revision_request_spec.rb` | 12 examples, 0 failures |
| `spec/features/presentation_revision_spec.rb` | 7 examples, 0 failures |
| Existing browser specs: navigation, meeting, diagrams, admin profiles, registration/theme | 28 examples, 0 failures |
| `bin/rubocop` | 319 files, no offenses |
| `bin/rails zeitwerk:check` | All good |
| `bin/brakeman --no-pager` | 0 warnings |
| `bin/importmap audit` | No vulnerable packages |
| `git diff --check` | Clean |

The full-suite failure was at `spec/features/admin/users_features_spec.rb:67` ("filter user"). Selenium reported `unknown error: Node with given id does not belong to the document` during the Turbo page swap. Later runs passed, so the failure is treated as intermittent, but it has **not** been proven unrelated to this revision.

The new tests cover:

- Delivery order: the second and first deliveries.
- Retrospective: image, link, alt text, and shared data; the legacy format.
- Captures: thumbnail and enlargement switch with the theme while keeping the slide position; missing or broken captures never show a broken image.
- Evidence: catalog paths exist, and the `publicado` flags match Git.
- Dialog keyboard behavior: initial focus, arrow keys do not change slides, focus stays in the dialog or browser UI, and Esc returns focus.
- Popovers close when the slide changes.
- Layout at 1920×1080: each main slide fits, measured by `scrollHeight`/`scrollWidth` and by elements outside the slide after fonts, images, and animations settle.
- Mobile at 390×844: no horizontal overflow.
- Conceptual multiplicity labels stay inside the canvas and appear in the enlarged copy.
- The print page count.
- The brand appears on public, auth, presentation, portal, and admin pages.
- The PNGs are transparent.

## Visual review evidence

The coordinator inspected screenshots taken with Chrome through Selenium:

- All 10 main slides at 1920×1080 in the dark and light themes. Everything fits: content height is at most the 964 px available.
- The visual concept in both themes, and its light lightbox.
- The retrospective, the functionalities slide, the evidence dialog, a popover, and the conceptual model.
- All main slides at 390×844, which scroll vertically only.
- Landing and login captures in both themes.
- The admin sidebar expanded and collapsed, and the auth and landing headers.
- The README rendered locally, with both versions of the `<picture>` logo.

The PDF was exported with `script/exportar_apresentacao_pdf.rb` for the active development profile "Segunda entrega — Status Report 2". It has 14 A4-landscape pages: the 10 main slides and 4 selected DER appendices, one slide per page. There are no blank pages and no printed dialogs or buttons. Pages 3–5 were inspected at 90 dpi; the diagram fills the page width and is legible.

## Manual pending items

- GitHub repository screenshot, and optional code screenshots.
- Team validation of the captures, the journeys, and the RFs.
- The retrospective's agreed actions, owners, and deadlines, if the team agrees on any.
- The retrospective date, if known.
- Use-case diagram (card #14) and occurrence-flow diagram (card #5).
- Presentation date for the second delivery (`data_apresentacao` in `config/presentation/entrega.yml`, currently blank).
- Rehearsal within 7 minutes; the estimate is 5 min 20 s.
- Restart any long-running `bin/dev` so the CSS watcher picks up the changes.
- Commit, push, merge, and deploy (none were done).

## Risks and limitations

- **Windowed browser:** on a Full HD monitor with a windowed browser (viewport about 1920×950), `capa`, `conceito-visual`, `retrospectiva`, `modelo-conceitual`, and `reunioes` scroll 13–80 px. Present in full screen (press **F**).
- **Popover placement:** it uses CSS anchor positioning. Browsers without that support center the popover.
- **Opening dialogs without JavaScript:** this relies on browser support for `commandfor`. When neither is available, the evidence is still in the "Evidências no repositório" appendix.
- **GitHub links:** they point to the published commit. For files changed since then, the linked version differs from the local file; the dialog says so.
- **Conceptual diagram text:** the multiplicities are small at 1080p. Zoom is available.
- **Outdated CSS:** the Tailwind watcher of a long-running `bin/dev`, started before the CSS changes, may serve an outdated build. Run `bin/rails tailwindcss:build` or restart `bin/dev`. The watcher was not stopped during this revision.
- **Registration approval:** `SGU_AUTO_APPROVE_REGISTRATIONS` defaults to `true` in every environment (`config/application.rb`). This was already the case before the revision; it was reported and not changed.
- **Deploy configuration:** `config/deploy.yml` still contains template placeholders.
- **Extra server:** a second development server was used on port 3100 for captures and the PDF (`tmp/pids/apresentacao-3100.pid`); it was stopped at the end of the revision. Start it again as described in `config/presentation/LEIAME.md` to export the PDF.

## Migrations

This revision created no migrations and did not change the database schema. The working tree also contains two uncommitted migrations dated 03/10/2026 from the earlier occurrence work: `db/migrate/20261003120000_unify_occurrence_publications.rb` and `db/migrate/20261003180000_add_occurrence_photo_order_and_map_location.rb`. `db/schema.rb` is also modified in the working tree; this revision did not run migrations or edit it. Apply them with `bin/rails db:migrate`, not `db:reset`, when reviewing the branch.

## Commit, push, and deploy

None. There was no commit, push, merge, merge request, or deployment in this revision. All changes remain in the local working tree.
