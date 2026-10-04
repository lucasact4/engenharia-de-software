# SGU Presentation Maintenance Guide

The public presentation is `/apresentacao`. Content comes from the YAML files in this directory; display profiles are stored in the database and edited through **Admin → Apresentação**. **Personalizar apresentação** changes only the current browser tab. This guide is in English; quoted slide names and controls match the Portuguese interface.

## Match slides to delivery requirements

**“Protótipo com o conceito visual do projeto”** is the second-delivery slide `conceito-visual`. Its content includes landing, login, and mobile screenshots in light and dark versions, the palette, the SGU brand card, and capture notes. **Protótipo de referência (Figma ou similar)** is optional material kept separately and is currently empty; the assignment does not require Figma.

Names come from `entrega.yml` → `entregas[].exigencias` for the profile's delivery. Headings, index, counters, administration, and customization share that source. **2ª entrega · Item 1** identifies the requirement; a number such as **04** is the current slide position and changes with selection. Use the title and stable ID rather than a fixed position.

Recommended profiles follow the assignment order: cover, delivery items, status-report items for the second delivery, then closing. Additional slides remain available but start disabled. Slides without a matching requirement use **Complementar**. Cover and closing are always visible.

### First delivery

| Item | Displayed name | Stable ID | Content |
| --- | --- | --- | --- |
| 1 | Lista de requisitos refinada | `requisitos` | Functional/nonfunctional requirements, acceptance criteria, refinement document/card. |
| 2 | Lista de ferramentas e tecnologias escolhidas | `arquitetura` | Technologies and versions; architecture may support the explanation. |
| 3 | Diagrama de casos de uso do sistema/App proposto | `casos-de-uso` | Enable the slide and provide its diagram in `diagramas.yml`; no subitems. |
| 4 | Ferramenta de monitoramento dos projetos ativa com os requisitos e links para ambientes — Trello | `gestao` | Trello board, project cards/requirements, environment links. |
| 5 | Planejamento dos próximos passos do projeto | `proximos-passos` | Demonstrable milestone, next steps, risks, dependencies. |
| 6 | Reflexão sobre o período (Lições aprendidas) | `retrospectiva` | Discussion points, agreed actions, lessons. |

### Second delivery — Status Report 2

| Item | Displayed name | Stable ID | Content |
| --- | --- | --- | --- |
| 1 | Protótipo com o conceito visual do projeto | `conceito-visual` | Landing, login, mobile screenshots (light and dark), palette, brand card, capture notes. Separate reference prototype only when available. |
| 2 | GitHub criado e estruturado com código fonte total ou parcial, contemplando as 2 funcionalidades do sistema proposto (Completas) | `funcionalidades` | GitHub capture and code structure, completeness criteria (dialog), functionality 1, functionality 2, other parts of the system (`extras`). |
| 3 | Imagem de uma retrospectiva | `retrospectiva` | Retrospective board image, legend, and link to the original session. |
| 4 | Modelo conceitual | `modelo-conceitual` | Conceptual diagram, technical production/team review/assumptions, distinction from the physical database model. |
| 5 | Evidência de reuniões de monitoramento do projeto | `reunioes` | Meeting records and genuine evidence. |
| Status report | O que foi feito desde a última entrega | `evolucao` | Commit timeline after the first delivery; capability overview is optional and initially disabled. |
| Status report | O que será feito até a próxima entrega | `proximos-passos` | Milestone, next steps, risks, dependencies. |
| Status report | O que aprendemos nesse sprint (Imagem de uma retrospectiva) | `status-report` | “Aprendi” cards as lessons, “Faltou” titles as points to improve, agreed actions (currently none), reference to the retrospective image. |

The second delivery has **eight content slides plus cover and closing**; the first has **six content slides plus cover and closing**. Ordering comes from `entrega.yml` → `exigencias[].slides` and applies to presentation, index, administration, customization, and PDF. Do not rename IDs or reorder requirements to add meeting images or update evidence.

Item 2 contains the repository and both functionalities on one slide. `evolucao` contains progress; `proximos-passos` contains planning; `status-report` contains lessons. The retrospective image belongs to item 3 and is referenced from the lessons slide, without duplication. The first-delivery retrospective instead shows points, actions, and lessons. See [Retrospective](#retrospective).

The conceptual model already exists in HTML/CSS and is distinct from the physical DER, use cases, and flow diagram. Technical production is complete; recorded team review and acceptance of assumptions remain separate.

Recommended profiles are defined in `db/seeds/presentation_profiles.rb`. The bootstrap creates missing profiles and preserves edited selections. The recommended **Segunda entrega — Status Report 2** has ten main slides (estimated 5 min 20 sec); **Primeira entrega** has eight (3 min 55 sec). These are recommended profile estimates, not a guarantee of the current database selection. Check the active profile in administration; do not run seeds to overwrite an edited profile. The previous explicit reorganization preserved a historical copy at `tmp/presentation-profiles-before-simplification-20261002.json`.

Optional material includes problem/proposal, scope, occurrence flow, repository details (`repositorio`), requirements conflicts, physical DER and its views, evidence, checklist, and speaking script/time. Technology and Trello slides belong to the first delivery and are outside the recommended second-delivery selection. Enabling extras changes the sequence and PDF. The second delivery has a seven-minute limit; check the estimate and rehearse.

## Content, catalog, and profiles

| Layer | Location | How to update |
| --- | --- | --- |
| Text, images, links, evidence | YAML files here and `app/assets/images/presentation/` | Versioned file changes. |
| Slides, content keys, times, defaults | `roteiro.yml`, partials in `app/views/presentations/slides/` | Versioned file changes. |
| Academic names, order, requirement mapping | `entrega.yml` → `exigencias` | Versioned file changes. |
| Selection for an occasion | `presentation_profiles` table | Admin → Apresentação. |
| Temporary adjustments | Current browser tab | Personalizar apresentação. |

A checkbox means **show content**, not **requirement fulfilled**. It does not create evidence or edit wording. Team confirmation is `confirmado_pela_equipe` in `entrega.yml` requirements. All catalog content is rendered in public HTML even when hidden by selection; do not store confidential data in these files.

## Prepare and use profiles

Run from the Dev Container terminal:

```bash
bin/rails db:migrate
bin/rails sgu:presentation:profiles
```

The profile task loads only `db/seeds/presentation_profiles.rb`, creating missing profiles without overwriting existing ones. Full development `db:seed` also resets demonstration account credentials, administrative access, and deletion status; use the targeted task for profiles. For a new database, follow the project's `db:prepare` setup.

If no profile is active, the page uses catalog `padrao` values and `entrega_padrao`. Opening the page never creates profiles.

1. Sign in as an administrator and open `/admin/apresentacao`. Ordinary accounts cannot manage profiles.
2. Choose **Novo perfil** or **Editar seleção**, then select a name, delivery, slides, and contents.
3. Delivery changes cover/footer, academic names, badges, checklist, and time limit. It does not automatically switch checkboxes; open the corresponding profile for another ready selection.
4. Cover and closing are mandatory. Disabling a slide retains its internal choices. A selected slide with no selected contents is omitted.
5. Use **Salvar configurações**; invalid values and keys outside the current catalog are rejected.
6. **Usar como padrão** chooses the public profile. Only one can be active, and the active profile cannot be deleted. **Visualizar** opens `/apresentacao?perfil=<id>` without changing the default.

The estimate sums selected main slides. Appendices do not add speaking time but do add PDF pages when selected. Actual duration depends on rehearsal.

### Temporary customization

**Personalizar apresentação** recalculates sequence, index, counter, progress, appendix access, and printing. **Concluir** closes the panel. **Restaurar padrão do perfil** or reloading discards temporary changes; they are saved neither in the database nor browser storage.

If the current slide is hidden, navigation moves to the next visible slide, or the previous one when necessary. Tab/Enter operate the panel; Esc closes it. Without JavaScript, reading mode uses the saved profile and has no customization panel.

### Stable keys and compatibility

Saved keys are `<slide ID>` and `<slide ID>.<content ID>`, such as `reunioes.registros`; titles and positions do not identify selections.

- Add a slide with `id`, `titulo`, `tempo`, and `padrao` in the catalog, and create its partial using underscores instead of hyphens in the filename.
- Add content under `conteudos` and mark its view block with `presentation_item`. `presentation_group` hides empty containers; `dentro_de` defines parent dependency.
- Missing keys use `padrao`. Change displayed titles without changing IDs.

`substitui` inherits legacy selections. Evolution, planning, retrospective, and lessons slide IDs were preserved; redundant `status-report.feito` and `status-report.proximo` contents were removed, while `status-report.aprendizados` remains valid. Saving resolves selections using the current catalog.

`repositorio` inherits `gestao` and `gestao.praticas`; `repositorio.praticas` inherits `gestao.praticas`. `reunioes` inherits `gestao` and `gestao.reunioes`; `reunioes.registros` inherits `gestao.reunioes`. All legacy keys present in a profile must be enabled for inheritance. Without legacy choices, the new key's default applies; an explicit new choice wins. Inspect the resolved selection before deleting old JSON.

## Where to update each item

| Content | Source |
| --- | --- |
| Team, course, links, deliveries, names, requirements, deadlines, limits | `entrega.yml` |
| Catalog, times, speakers, defaults, appendices | `roteiro.yml` |
| Problem, audience, conflicts, requirements, acceptance criteria | `requisitos.yml` |
| Milestones, unpublished references, periods, capabilities, first-delivery date | `evolucao.yml` |
| Visual captures (dark and light), palette, separate prototype | `conceito_visual.yml` |
| GitHub capture, published commit, both journeys, code evidence, extras | `funcionalidades.yml` |
| Diagram production, team review, version, origin | `diagramas.yml` |
| Tables, columns, relationships, concepts, architecture, positions | `data_diagrams.yml` |
| Diagram rendering/styles | `app/views/presentations/shared/_er_diagram.html.erb`, `app/assets/stylesheets/presentation/diagrams.css` |
| Technologies, local logos, version sources, rationale | `tecnologias.yml` |
| Trello, environments, repository practices, meetings | `gestao.yml` |
| Retrospective board, link, columns and cards, agreed actions | `retrospectiva.yml` |
| Milestone, next-step priorities and their dependencies, risks, dependencies | `planejamento.yml` |
| SGU logo in slides and pages | `sgu_brand` in `app/helpers/brand_helper.rb`; files in `app/assets/images/brand/` |

`status-report` reads only `retrospectiva.yml`. Reading mode `/apresentacao?modo=leitura` shows dashed maintenance notes with source filenames; presenting and printing remove those notes.

Valid states are `implementado`, `parcial`, `planejado`, `aguardando_decisao`, and `aguardando_evidencia`. Use implemented only with verifiable technical evidence. Team confirmation and requirements acceptance require their own recorded review.

## Implemented journeys and genuine remaining evidence

The two journeys are already chosen, implemented, and tested in `funcionalidades.yml`:

1. **Registrar ocorrência e acompanhar o atendimento**: author submits an occurrence, coordination assesses/assigns/resolves it, and the author follows its status without receiving internal notes.
2. **Publicar e interagir no mural**: the same occurrence post reaches its allowed audience, readers comment/reply/like/save/follow, and moderation revokes disclosure/interactions. Verified-author publication and same-post administrator approval are implemented.

Their `evidencias` and `testes` identify the actual implementation and specs; see [Functionalities and code evidence](#functionalities-and-code-evidence). Empty `requisitos` lists mean the academic requirement document has not yet mapped RFs to these journeys; they do not mean the application is unimplemented. Validate human acceptance and evidence separately.

The meeting of **03/10/2026 around 18:20**, held on Google Meet, is recorded in `gestao.yml` with four genuine screenshots. Visible participant names and discussion topics are documented, with a note about truncated names. `decisoes: []` remains intentional: next actions and owners have not been formalized. The screenshot times 18:21, 18:23, 18:24, and 18:37 do not establish the meeting's ending or duration. The screenshots show the version demonstrated at that meeting, including its observed problems; they do not prove a deployment, acceptance of requirements, or a retrospective.

| Item still needing team work | Action |
| --- | --- |
| Requirements, card #13 | Resolve conflicts, approve RF/RNF and acceptance criteria, record document/version. |
| Use cases, card #14, and occurrence flow, card #5 | Supply approved diagrams with origin/version/date; neither replaces the conceptual model. |
| Visual concept | Review the 04/10/2026 captures and their demonstration labels; separate prototype only if chosen. |
| Both implemented functionalities | Map approved requirements, perform team acceptance, and retain evidence; do not describe the journeys as unchosen or awaiting implementation. |
| Conceptual model | Record team review of multiplicities and assumptions. Optional photos, private visibility, and operational roles still require requirements acceptance. |
| Retrospective | The board image, link, and cards are recorded. Still missing: the proven date of the retrospective and any agreed actions with owners and deadlines. |
| Meetings | Keep genuine records and evidence current; confirm metadata and document only actual discussions/decisions. |
| Trello/environments | Add the card #11 link and verify teacher access. Add a staging URL only after an actual deployment. |
| GitHub capture | Add the manual repository-page screenshot (see [Functionalities and code evidence](#functionalities-and-code-evidence)). |
| Next delivery | Agree on milestone, owners, dates, and rehearse within seven minutes. |

Blank fields remain explicit pending work. Set `confirmado_pela_equipe: true` only after review. Timeline links need actual published commits; local changes must not receive invented hashes.

## Retrospective

`retrospectiva.yml` is the single source for the `retrospectiva` slide and the `status-report` slide. `Presentation::Retrospective` (`app/models/presentation/retrospective.rb`) reads it.

| Field | Meaning |
| --- | --- |
| `data` | Actual date of the retrospective. It is blank because the date is not proven. The 03/10/2026 meeting in `gestao.yml` is a different event. |
| `ferramenta`, `formato` | Tool (`FunRetrospectives`) and the columns used (“Gostei · Aprendi · Faltou”). |
| `link` | Public session address. Only `https://` values are accepted. Current value: `https://app.funretrospectives.com/session/-P348lsyv9l5kgdtJO7_` (keep the trailing underscore). |
| `imagem` | `presentation/retrospectiva/quadro-gostei-aprendi-faltou.png`, relative to `app/assets/images`. It is the original capture (895×782, unedited, SHA-256 starting with `2cecb2e3`). |
| `imagem_ampliada` | Optional. Another resolution for the enlarged view; blank uses `imagem`. |
| `imagem_descricao` | Alternative text for the image. |
| `colunas` | Faithful transcription of the board, in board order. Column ids are `gostei`, `aprendi`, and `faltou`; each has `titulo` and `cartoes` with `titulo` and `texto`. |
| `acoes` | Actions agreed by the team, each with `acao`, `responsavel`, and `prazo`. It is empty because no action has been formalized. |
| `pontos`, `licoes` | Legacy first-delivery format. Still accepted, and used only when `colunas` is absent. |

The `retrospectiva` slide shows the board image, which opens in the existing lightbox, a legend, an **Abrir retrospectiva** button that opens the session in a new tab (`rel="noopener noreferrer"`), and the URL as text, which stays clickable in the PDF. The session is not embedded; there is no iframe.

The `status-report` slide reads the same data. The four “Aprendi” cards are shown as lessons, and the four “Faltou” titles are shown as points to improve. These points are explicitly labelled as not yet agreed actions. Add entries to `acoes` only after the team agrees on them, with a real owner and deadline.

## Visual concept captures

`conceito_visual.yml` → `capturas` lists the captured screens. Image paths are relative to `app/assets/images`.

| Field | Meaning |
| --- | --- |
| `imagem`, `imagem_ampliada`, `alt` | Dark-theme version (the system default). |
| `claro` | Light-theme version of the same route, size, and state: `{ imagem, imagem_ampliada, alt }`. Without `claro`, the single image is used for both themes, so older entries remain valid. |
| `rota`, `largura` | Captured route and viewport size, such as `1440 × 1000 px`. |
| `estado`, `demonstrativo` | State of the captured screen, and whether it shows example data. |
| `nota` | Secondary detail, shown inside the slide's information button (Popover API). |
| `capturado_em`, `ambiente` | Capture date and environment, at the top of the file. |

Captures switch with the system theme. They use the same `sgu.theme` localStorage key and `data-theme` attribute as the rest of the application; there is no second preference store. The lightbox shows the version of the active theme, and print uses the light version.

`paleta` lists the six real colors from `app/assets/stylesheets/theme.css`, each with `nome`, `hex`, and `uso`. The `conceito-visual.marca` content shows the SGU brand card.

The current captures were regenerated on **04/10/2026** with the new brand. To regenerate them, start the additional server described in [Run and export PDF](#run-and-export-pdf) and run, with Selenium active:

```bash
bundle exec ruby script/capturar_conceito_visual.rb [output dir]
```

The default output is `tmp/conceito_visual/`. Review the images, then copy them to `app/assets/images/presentation/`. Dark files keep the existing names (`landing-desktop.png`, `landing-completa.png`, `landing-mobile.png`, `entrar-desktop.png`); light files add `-claro` (for example, `landing-desktop-claro.png`). Update `capturado_em` and `ambiente`. Keep demonstration credentials and unrelated personal data out of captures, and set `commit` only when it matches the captured code.

## Functionalities and code evidence

`funcionalidades.yml` has these parts:

| Key | Meaning |
| --- | --- |
| `repositorio` | `captura` (manual screenshot of the GitHub repository page), `alt`, and `legenda`. While `captura` is empty, the slide shows a discreet placeholder, never a broken image. |
| `publicacao` | `commit` is the full SHA of `origin/main` used for code links (currently `658bfde07f9fb7f619768538a1c8648e669c0204`); `rotulo` is its label (“main · 02/10/2026”). |
| `criterios` | Completeness criteria, shown in a dialog. |
| `itens[]` | Each journey: `resumo`, `fluxo` (three short labels), `jornada` (detailed steps), `evidencias`, `testes`, and `validacao`. |
| `evidencias[]` | Explicit catalog of files: `tipo` (`controller`, `model`, `view`, `service`, or `policy`), `caminho`, `papel`, `publicado`, and optional `captura`. |
| `extras` | Other parts of the system, each with `nome`, `estado`, and `nota`. |

`caminho` must be a relative path under `app/`, `config/`, `db/`, `lib/`, or `spec/`, without `..`. `publicado: true` means the file exists in the `publicacao.commit` commit, and the dialog links to `https://github.com/<repository>/blob/<sha>/<path>`. `publicado: false` is shown as “Somente na cópia local”. The server never reads files from URL parameters; only this catalog is displayed.

**Ver implementação** opens a modal `<dialog>`. Focus moves to its title, Esc closes it, and focus returns to the button. Arrow keys do not change slides while it is open, and long content scrolls inside the dialog. The buttons also carry `commandfor` and `command="show-modal"`, so modern browsers open the dialog without JavaScript.

To add the GitHub capture, save the PNG as `app/assets/images/presentation/github/repositorio.png` and set `repositorio.captura: "presentation/github/repositorio.png"`. To add a code capture, save it in the same folder (for example, `app/assets/images/presentation/github/alerts-controller.png`) and set `captura` on that evidence.

When new code is merged into `main`, update `publicacao.commit` and every `publicado` flag. `spec/models/presentation_spec.rb` checks the flags against Git when the commit exists locally.

## Evolution and planning

`evolucao.yml` → `marcos` lists milestones. `commit` is the full SHA of a published commit and becomes a GitHub link. For unpublished work, leave `commit` blank and set `referencia`, the text shown instead of the link. `periodo` is an optional date-range label; `data` stays the start date.

Milestones after the first delivery (23/09/2026):

- 27/09: SGU identity (`da70a47`, published).
- 02/10: data model and presentation profiles (`658bfde`, PRs #11 and #12).
- 03/10: alignment meeting, around 18:20.
- 03–04/10: occurrences, handling, and board (local commits and unpublished changes).
- 04/10: retrospective, brand, and presentation (local changes).

`planejamento.yml` → `proximos_passos` lists four priorities, each with an optional `depende_de`. No dates or owners are recorded because the team has not decided them.

The use-case diagram review has no evidence in the repository, so neither file lists it as done.

## Meeting record and image gallery

Meeting records remain in `gestao.yml` → `reunioes`; the stable selection keys are still `reunioes` and `reunioes.registros`.

| Field | Meaning |
| --- | --- |
| `data`, `horario`, `tipo`, `plataforma` | Actual date, approximate or recorded time, meeting type, and meeting platform. Do not infer duration from screenshots. |
| `participantes`, `participantes_nota` | Known participant names and limits of that evidence, such as a truncated display name. |
| `pauta` | Discussion topics supported by the meeting record. |
| `decisoes`, `nota` | Recorded decisions and any remaining follow-up; keep an empty list when no decisions have been formalized. |
| `evidencias` | Gallery entries, each containing an asset `imagem`, visible `legenda`, and descriptive `alt`. |
| `evidencia_imagem`, `evidencia_url` | Compatible legacy single-image and public-link fields; existing records do not need conversion. |

Image paths are relative to `app/assets/images`. The current four assets are:

- `presentation/reunioes/2026-10-03/01-painel.png`
- `presentation/reunioes/2026-10-03/02-administracao.png`
- `presentation/reunioes/2026-10-03/03-rails.png`
- `presentation/reunioes/2026-10-03/04-ambiente.png`

The copied originals were hash-checked against the supplied files and remain unchanged. `app/views/presentations/slides/_reunioes.html.erb` renders each entry through the shared `_figure.html.erb` component. Clicking or keyboard-activating **Ampliar** opens the original in the existing lightbox; Esc closes it and restores focus to the trigger. Without JavaScript, **Abrir imagem** remains available. Print excludes those controls and uses the compact gallery; retain meaningful captions and alt text when adding evidence.

The navigation/gallery verification passed **17 examples, 0 failures**, seed **58478**. The gallery was reviewed on desktop and mobile. A selected cover/meeting/closing profile exported to **three PDF pages**, with all four meeting images on its one meeting page; this does not imply every customized profile has three pages. The final review rechecked the mobile gallery and printed meeting image without a focus outline. Recheck print layout after adding meetings or longer text. A previous integrated run, before the retrospective, brand, and presentation revision of 04/10/2026, recorded **681 examples, 0 failures**, seed **30669**, and **97.09%** line coverage (4,148 of 4,272 lines, SimpleCov). It does not validate the later changes; current results are recorded in [the presentation and brand review](../../docs/apresentacao-identidade-sgu-revisao.md). The meeting date remains 03/10/2026.

The meeting captures are a faithful historical record of the version demonstrated on 03/10/2026. The visual-concept captures were regenerated later, on 04/10/2026, in both themes with the new brand; see [Visual concept captures](#visual-concept-captures).

## HTML/CSS diagrams and technology cards

DER, conceptual model, and architecture use `_er_diagram.html.erb` and `PresentationDiagram`. Entities, columns, relationships, and coordinates come from the catalog; row counts affect height and paths are calculated by the model. The DER displays `db/schema.rb`'s version. Update `tables`, `foreign_keys`, and relevant views in `data_diagrams.yml` after migrations; operational/social/infrastructure appendices should cover all columns. FK `required`/`unique` define cardinalities; polymorphic relationships are dashed entries in `relations`.

The conceptual diagram (`diagrams.conceptual`) is laid out wide, at 1350×580, with the same 11 concepts and 20 relations. Two options control it: `ports: distributed` places one port per connection along each side of a concept, and `cardinality_labels: true` draws the multiplicities at both ends of each relation. Its `notes` list is rendered under “Relações e cardinalidades”; the former “Dimensões distintas” box is now one of these notes. The physical DERs are unchanged.

`presentation_profiles` belongs to infrastructure, not an invented SGU business concept. Selecting an entity highlights connections and cardinalities; **Ampliar** keeps the interaction. Mobile diagrams use internal scrolling. Styles are organized under `app/assets/stylesheets/presentation/`, imported by `presentation.css`; review print after changing positions.

Technical production, team review, and assumptions in `diagramas.yml` are independent. The conceptual model was produced in card #6; revise it instead of creating a duplicate. Record reviewers, date, version, and accepted assumptions. Team-supplied images belong in `app/assets/images/presentation/` with paths relative to `app/assets/images`. Pending use-case/flow images may use PNG/SVG; existing native diagrams stay HTML/CSS. Only public HTTP(S) URLs become links; filesystem paths are rendered as text.

The SGU logo is rendered by `sgu_brand(layout, tone:)` in `app/helpers/brand_helper.rb`. Layouts are `:symbol`, `:horizontal`, and `:vertical`. Tones are `:auto` (follows the page theme), `:on_light`, `:on_dark`, and `:dark_surface` (negative on screen, standard version in print). The files come from `app/assets/images/brand/`; see the main [README](../../README.md#brand).

Technology cards use local logos or a neutral symbol; assets are in `app/assets/images/presentation/logos/`, with sources/conditions in `tecnologias.yml`. A neutral symbol is not a brand logo. With **Versões** selected inside **Tecnologias utilizadas**, mouse hover or keyboard focus shows a tooltip, Esc closes it, and **Mostrar versões** expands data below all cards. Disabling the content hides tooltips/data/control. Printing and no-JavaScript mode show selected versions even when collapsed on screen.

Version `rotulo` uses `gem`, `ruby_version_file: true`, `sqlite_engine: true`, or explanatory `texto`. Integration gem versions do not imply underlying technology versions: Tailwind separates Rails integration from CLI; SQLite separates Ruby adapter from database engine.

## Run and export PDF

Use `bin/dev` in the Dev Container and open `http://localhost:3000/apresentacao`. Avoid starting a second copy if it is already running; inspect the VS Code **Ports** forwarding when another project uses the same host port.

The layout target is a 1920×1080 viewport (full screen on a Full HD monitor) in presenting mode with the default second-delivery selection: every main slide fits without scrolling, as measured by `spec/features/presentation_revision_spec.rb`. In a browser window that is not full screen (about 1920×950), some slides scroll a little, so press **F** for full screen before presenting. On mobile, slides scroll vertically, never horizontally.

Use **Imprimir / salvar PDF** or Ctrl+P for A4 landscape, one slide per page, including selected appendices. Browser printing respects temporary selection, removes controls/maintenance notes, and needs background graphics enabled. Dialogs and information buttons are not printed; instead, print shows compact evidence lines (file basenames and tests) and the short notes of partial items.

For Selenium export, run an additional presentation server in a separate Dev Container terminal:

```bash
RAILS_DEVELOPMENT_HOSTS=rails-app bin/rails server -b 0.0.0.0 -p 3100 -P tmp/pids/apresentacao-3100.pid
```

With Selenium active, run:

```bash
bundle exec ruby script/exportar_apresentacao_pdf.rb
```

The script reads `http://rails-app:3100/apresentacao?modo=leitura` and writes `tmp/apresentacao/sgu-segunda-entrega.pdf`; a destination argument is optional. `localhost` inside Selenium is not the Rails container. Confirm forwarded ports 3000/3100 and stop only the additional server with Ctrl+C after export.

The script loads a new page with the active profile, ignoring temporary selections from another tab. For a saved profile:

```bash
APRESENTACAO_URL="http://rails-app:3100/apresentacao?modo=leitura&perfil=<id>" bundle exec ruby script/exportar_apresentacao_pdf.rb
```

Replace `<id>` using administration's **Visualizar** link. The Dev Container defaults `SELENIUM_REMOTE_URL` to `http://selenium:4444/wd/hub`; a different host must be reachable by Selenium and allowed by Rails. Inspect every PDF page, images, clipping, diagrams, text, and links. `tmp/` is ignored by Git; share the final PDF explicitly.

## Validation

JavaScript features require Selenium; Capybara starts its own server and does not need port 3100:

```bash
bundle exec rspec spec/models/presentation_spec.rb spec/models/presentation/selection_spec.rb spec/models/presentation_profile_spec.rb \
  spec/models/presentation_diagram_spec.rb spec/policies/presentation_profile_policy_spec.rb spec/requests/presentations_request_spec.rb \
  spec/requests/admin/presentation_profiles_request_spec.rb spec/helpers/presentations_helper_spec.rb \
  spec/features/presentation_navigation_spec.rb spec/features/presentation_meeting_spec.rb \
  spec/features/presentation_diagrams_spec.rb spec/features/admin/presentation_profiles_features_spec.rb \
  spec/models/presentation/retrospective_spec.rb spec/helpers/brand_helper_spec.rb \
  spec/requests/presentation_revision_request_spec.rb spec/features/presentation_revision_spec.rb
```

These checks cover catalog keys, images/links, saved selection, administration restrictions, navigation, customization, print, requirement titles, and DER agreement with the test schema. Navigation tests include technology tooltips/mobile expansion and real script export with loaded logos. `presentation_meeting_spec.rb` verifies the four originals, lightbox focus restoration, mobile layout, and a three-page meeting-only export; it restores the viewport after capturing. `presentation_revision_spec.rb` measures the 1920×1080 layout target and phone width without horizontal scrolling, and checks theme-dependent captures, the evidence dialog, popovers, conceptual multiplicities, and printing without dialogs. Automated tests do not approve academic requirements, verify the teacher's external-link access, or establish actual speaking duration. Read the PDF, check links without the team's session, and rehearse.

See [the earlier presentation review](../../docs/presentation-upgrade-review.md) for its dated handoff and [the current occurrence/social guide](../../docs/occurrence-social-flow.md) for application rules and validation. The focused meeting-gallery results and the previous integrated run are recorded above; current results are in [the presentation and brand review](../../docs/apresentacao-identidade-sgu-revisao.md). Existing alerts without a post are not silently disclosed by visiting their detail: the author must confirm an audience before the new mural creates that legacy record's publication. See the occurrence/social guide for that compatibility boundary.
