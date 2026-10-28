# SGU Presentation Maintenance Guide

The public presentation is `/apresentacao`. Content comes from the YAML files in this directory; display profiles are stored in the database and edited through **Admin → Apresentação**. **Personalizar apresentação** keeps temporary choices in the current tab; **Baixar PDF** sends a copy to the server for that export without saving them. This guide is in English; quoted slide names and controls match the Portuguese interface.

## Match slides to delivery requirements

**“Protótipo com o conceito visual do projeto”** is the second-delivery slide `conceito-visual`. Its content includes landing, login, and mobile screenshots in light and dark versions, the palette, the SGU brand card, and capture notes. **Protótipo de referência (Figma ou similar)** is optional material kept separately and is currently empty; the assignment does not require Figma.

Names come from `entrega.yml` → `entregas[].exigencias` for the profile's delivery. An optional `slides[].titulo` supplies a shorter display title; otherwise the full requirement text is used. Headings, index, counters, administration, and customization share that source. When the display title differs, **Ver exigência completa** shows the full requirement in the heading information control. **2ª entrega · Item 1** identifies the requirement; a number such as **04** is the current slide position and changes with selection. Use the title and stable ID rather than a fixed position.

Recommended profiles follow the assignment order: cover, delivery items, status-report items for the second delivery, then closing. Additional slides remain available but start disabled. Slides without a matching requirement use **Complementar**. Cover and closing are always visible.

### First delivery

| Item | Requirement | Stable ID | Content |
| --- | --- | --- | --- |
| 1 | Lista de requisitos refinada | `requisitos` | Functional/nonfunctional requirements, acceptance criteria, refinement document/card. |
| 2 | Lista de ferramentas e tecnologias escolhidas | `arquitetura` | Technologies and versions; architecture may support the explanation. |
| 3 | Diagrama de casos de uso do sistema/App proposto | `casos-de-uso` | Enable the slide and provide its diagram in `diagramas.yml`; no subitems. |
| 4 | Ferramenta de monitoramento dos projetos ativa com os requisitos e links para ambientes — Trello | `gestao` | Trello board, project cards/requirements, environment links. |
| 5 | Planejamento dos próximos passos do projeto | `proximos-passos` | Demonstrable mural milestone and five future priorities. |
| 6 | Reflexão sobre o período (Lições aprendidas) | `retrospectiva` | Discussion points, agreed actions, lessons. |

### Second delivery — Status Report 2

| Item | Requirement | Stable ID | Content |
| --- | --- | --- | --- |
| 1 | Protótipo com o conceito visual do projeto | `conceito-visual` | Landing, login, mobile screenshots (light and dark), palette, brand card, capture notes. Separate reference prototype only when available. |
| 2 | GitHub criado e estruturado com código fonte total ou parcial, contemplando as 2 funcionalidades do sistema proposto (Completas) | `funcionalidades` | GitHub capture and code structure, completeness criteria (dialog), functionality 1, functionality 2, other parts of the system (`extras`). |
| 3 | Imagem de uma retrospectiva | `retrospectiva` | Retrospective board image, legend, and link to the original session. |
| 4 | Modelo conceitual | `modelo-conceitual` | Conceptual diagram, production and implemented model rules, distinction from the physical database model. |
| 5 | Evidência de reuniões de monitoramento do projeto | `reunioes` | Meeting records and genuine evidence. |
| Status report | O que foi feito desde a última entrega | `evolucao` | Chronological project timeline from the first landing, including the first delivery; capability overview is optional. |
| Status report | O que será feito até a próxima entrega | `proximos-passos` | Demonstrable mural milestone and five future priorities. |
| Status report | O que aprendemos nesse sprint (Imagem de uma retrospectiva) | `status-report` | “Aprendi” cards and a crop of that column from the original board, with links to the full retrospective. |

The current short titles are **GitHub e duas funcionalidades completas** and **O que aprendemos nesse sprint**. Their full assignment wording remains available in the information control.

The second delivery has **eight content slides plus cover and closing**; the first has **six content slides plus cover and closing**. Ordering comes from `entrega.yml` → `exigencias[].slides` and applies to presentation, index, administration, customization, and PDF. Do not rename IDs or reorder requirements to add meeting images or update evidence.

Item 2 contains the repository and both functionalities on one slide. `evolucao` contains progress; `proximos-passos` contains planning; `status-report` contains lessons. The complete retrospective board belongs to item 3; the lessons slide uses the “Aprendi” crop and links back to the full board. The first-delivery retrospective instead shows points, actions, and lessons. See [Retrospective](#retrospective).

The conceptual model already exists in HTML/CSS and is distinct from the physical DER, use cases, and flow diagram. Production and the implemented model rules are shown separately; team approval is not a presentation requirement or checklist gate.

Recommended profiles are defined in `db/seeds/presentation_profiles.rb`. The bootstrap creates missing profiles and preserves edited selections. The recommended **Segunda entrega — Status Report 2** has ten main slides; **Primeira entrega** has eight. Per-slide durations and calculated estimates are not shown in the public index or customization panel. The controllable presentation timer is independent of saved slide timing metadata. Check the active profile in administration; do not run seeds to overwrite an edited profile. The previous explicit reorganization preserved a historical copy at `tmp/presentation-profiles-before-simplification-20261002.json`.

Optional material includes problem/proposal, scope, occurrence flow, repository details (`repositorio`), requirements conflicts, physical DER and its views, evidence, checklist, and speaking script/time. Technology and Trello slides belong to the first delivery and are outside the recommended second-delivery selection. Enabling extras changes the sequence and PDF. The second delivery has a seven-minute limit; use the timer and rehearse.

## Content, catalog, and profiles

| Layer | Location | How to update |
| --- | --- | --- |
| Text, images, links, evidence | YAML files here and `app/assets/images/presentation/` | Versioned file changes. |
| Slides, content keys, times, defaults | `roteiro.yml`, partials in `app/views/presentations/slides/` | Versioned file changes. |
| Requirement wording, display titles, order, mapping | `entrega.yml` → `exigencias`, including `slides[].titulo` | Versioned file changes. |
| Selection for an occasion | `presentation_profiles` table | Admin → Apresentação. |
| Temporary adjustments | Current browser tab; copied to the server for PDF export | Personalizar apresentação. |

A checkbox means **show content**, not **requirement fulfilled**. It does not create evidence or edit wording. Team-approval notices and confirmation counts have been removed from the slides and checklist. The parser still accepts the legacy `confirmado_pela_equipe` field for compatibility; it is not used as a display gate. All catalog content is rendered in public HTML even when hidden by selection; do not store confidential data in these files.

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

Catalog timing metadata remains available for maintenance, but public navigation does not display per-slide times or a summed speaking estimate. Appendices add PDF pages when selected. Internal appendix links appear only when their target is selected in the saved profile or temporary customization. At this review, the development active profile enables all four DER appendices; default test screenshots intentionally disable them. An absent DER link in those screenshots is not evidence that the appendix is unavailable or that the development profile should be reset. **Voltar à apresentação** has a valid native link before JavaScript runs: server rendering targets the visible conceptual-model slide, or the first visible main slide if the conceptual model is not selected. JavaScript updates the native `href` to the last visible main slide that opened the appendix and restores focus on return. If that origin is hidden, it falls back to the visible conceptual model or first available main slide. The native link stays visible and clickable in PDF, including first-delivery profiles and temporary selections that hide the conceptual model. Actual duration depends on rehearsal.

### Temporary customization

**Personalizar apresentação** recalculates sequence, index, counter, progress, appendix access, and printing. **Concluir** closes the panel. **Restaurar padrão do perfil** or reloading discards temporary changes; they are saved neither in the database nor browser storage.

**Baixar PDF** submits the current checkbox choices and theme to the server only for generating that download. It preserves the profile being previewed and does not update its saved selection.

If the current slide is hidden, navigation moves to the next visible slide, or the previous one when necessary. Tab/Enter operate the panel; Esc closes it. Without JavaScript, reading mode uses the saved profile and has no customization panel.

### Stable keys and compatibility

Saved keys are `<slide ID>` and `<slide ID>.<content ID>`, such as `reunioes.registros`; titles and positions do not identify selections.

- Add a slide with `id`, `titulo`, `tempo`, and `padrao` in the catalog, and create its partial using underscores instead of hyphens in the filename.
- Add content under `conteudos` and mark its view block with `presentation_item`. `presentation_group` hides empty containers; `dentro_de` defines parent dependency.
- Missing keys use `padrao`. Change displayed titles without changing IDs.
- `tema: escuro` selects the impact-slide styling variant; it follows the application's dark/light theme rather than forcing a fixed dark-green background. Print preserves the selected presentation theme.

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
| Diagram production, implemented model rules, version, origin | `diagramas.yml` |
| Tables, columns, relationships, concepts, architecture, positions | `data_diagrams.yml` |
| Diagram rendering/styles | `app/views/presentations/shared/_er_diagram.html.erb`, `app/assets/stylesheets/presentation/diagrams.css` |
| Technologies, local logos, version sources, rationale | `tecnologias.yml` |
| Trello, environments, repository practices, meetings | `gestao.yml` |
| Retrospective board, link, columns and cards, agreed actions | `retrospectiva.yml` |
| Demonstrable mural milestone, theme-dependent capture, five future priorities | `planejamento.yml` |
| SGU logo in slides and pages | `sgu_brand` in `app/helpers/brand_helper.rb`; files in `app/assets/images/brand/` |

`status-report` reads only `retrospectiva.yml`. Reading mode `/apresentacao?modo=leitura` shows dashed maintenance notes with source filenames; presenting and printing remove those notes.

Valid states are `implementado`, `parcial`, `planejado`, `aguardando_decisao`, and `aguardando_evidencia`. Use implemented only with verifiable technical evidence. Presentation selection and technical status do not establish deployment or academic grading.

## Implemented journeys and genuine remaining evidence

The two journeys are already chosen, implemented, and tested in `funcionalidades.yml`:

1. **Registrar ocorrência e acompanhar o atendimento**: author submits an occurrence, coordination assesses/assigns/resolves it, and the author follows its status without receiving internal notes.
2. **Publicar e interagir no mural**: the same occurrence post reaches its allowed audience, readers comment/reply/like/save/follow, and moderation revokes disclosure/interactions. Verified-author publication and same-post administrator approval are implemented.

Their `evidencias` and `testes` identify the actual implementation and specs; see [Functionalities and code evidence](#functionalities-and-code-evidence). Empty `requisitos` lists mean the academic requirement document has not yet mapped RFs to these journeys; they do not mean the application is unimplemented. Keep requirement mapping and supporting evidence accurate; team approval is not a blocker for displaying these implemented journeys.

The meeting of **03/10/2026 around 18:20**, held on Google Meet, is recorded in `gestao.yml` with four genuine screenshots. Visible participant names and discussion topics are recorded in the source YAML. `decisoes: []` remains intentional: next actions and owners have not been formalized. The screenshot times 18:21, 18:23, 18:24, and 18:37 do not establish the meeting's ending or duration. The screenshots show the version demonstrated at that meeting, including its observed problems; they do not prove a deployment, acceptance of requirements, or a retrospective.

| Remaining artifact or operational work | Action |
| --- | --- |
| Requirements, card #13 | Resolve documented conflicts and map the RF/RNF identifiers to the implemented journeys. |
| Use cases, card #14 | Leadership reports the diagram complete, but its image/version/origin/date are absent from the repository. Attach the artifact to display it; do not describe the work itself as awaiting team approval. |
| Occurrence flow, card #5 | Supply the separate flow artifact and its metadata; it does not replace the conceptual model. |
| Retrospective | The original board, link, transcription, and “Aprendi” crop are recorded. Its date is unproven, and no actions with owners/deadlines are recorded. Do not infer these from the meeting. |
| Meetings | Keep genuine records and evidence current; document only actual discussions and decisions. |
| Trello/environments | Add the card #11 link and check external access. Add a staging URL only after an actual deployment. |
| Code captures | The supplied GitHub repository screenshot is attached unchanged. Optional code screenshots are still absent; published file links already provide code evidence. |
| Next delivery | Rehearse within seven minutes. Local email preview and official location seeds are future work, not implemented features. |

Missing artifacts remain factual evidence gaps. Do not introduce a team-approval checklist to replace them. Internal source references must identify actual commits; leave hashes blank where no commit evidence exists. The visible timeline has no source buttons.

## Retrospective

`retrospectiva.yml` is the single source for the `retrospectiva` slide and the `status-report` slide. `Presentation::Retrospective` (`app/models/presentation/retrospective.rb`) reads it.

| Field | Meaning |
| --- | --- |
| `data` | Actual date of the retrospective. It is blank because the date is not proven. The 03/10/2026 meeting in `gestao.yml` is a different event. |
| `ferramenta`, `formato` | Tool (`FunRetrospectives`) and the columns used (“Gostei · Aprendi · Faltou”). |
| `link` | Public session address. Only `https://` values are accepted. Current value: `https://app.funretrospectives.com/session/-P348lsyv9l5kgdtJO7_` (keep the trailing underscore). |
| `imagem` | `presentation/retrospectiva/quadro-gostei-aprendi-faltou.png`, relative to `app/assets/images`. It is the original capture (895×782, unedited, SHA-256 starting with `2cecb2e3`). |
| `imagem_ampliada` | Optional. Another resolution for the enlarged view; blank uses `imagem`. |
| `imagem_descricao` | Alternative text for the complete board image. |
| `aprendizados_imagem`, `aprendizados_imagem_descricao` | Asset path and alternative text for the lessons column. Current asset: `presentation/retrospectiva/aprendi.png`, the user-supplied crop of the original “Aprendi” column, preserved unchanged. |
| `colunas` | Faithful transcription of the board, in board order. Column ids are `gostei`, `aprendi`, and `faltou`; each has `titulo` and `cartoes` with `titulo` and `texto`. |
| `acoes` | Actions agreed by the team, each with `acao`, `responsavel`, and `prazo`. It is empty because no action has been formalized. |
| `pontos`, `licoes` | Legacy first-delivery format. Still accepted, and used only when `colunas` is absent. |

The `retrospectiva` slide shows the board image, which opens in the existing lightbox, a legend, an **Abrir retrospectiva** button that opens the session in a new tab (`rel="noopener noreferrer"`), and the URL as text, which stays clickable in the PDF. The session is not embedded; there is no iframe.

The `status-report` slide reads the four “Aprendi” cards as lessons, displays `aprendizados_imagem`, and links to the full board/session. It has no “Faltou” block or action placeholder. The complete original board and transcription still preserve all three columns. Add entries to `acoes` only for actual recorded actions with an owner and deadline.

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

Captures switch with the system theme. They use the same `sgu.theme` localStorage key and `data-theme` attribute as the rest of the application; there is no second preference store. The lightbox and PDF show the version of the active theme; PDF no longer forces light captures.

`paleta` lists the six application colors from `app/assets/stylesheets/theme.css`, each with `nome`, `hex`, and `uso`. The softer sage light palette is scoped to the presentation in `app/assets/stylesheets/presentation/experience.css`; it does not replace the rest of the application theme. The `conceito-visual.marca` content shows the SGU brand card.

The current captures were regenerated on **04/10/2026** with the new brand. To regenerate them, start the additional server described in [Run and export PDF](#run-and-export-pdf) and run, with Selenium active:

```bash
bundle exec ruby script/capturar_conceito_visual.rb [output dir]
```

The default output is `tmp/conceito_visual/`. Review the images, then copy them to `app/assets/images/presentation/`. Dark files keep the existing names (`landing-desktop.png`, `landing-completa.png`, `landing-mobile.png`, `entrar-desktop.png`); light files add `-claro` (for example, `landing-desktop-claro.png`). Update `capturado_em` and `ambiente`. Keep demonstration credentials and unrelated personal data out of captures, and set `commit` only when it matches the captured code.

## Functionalities and code evidence

`funcionalidades.yml` has these parts:

| Key | Meaning |
| --- | --- |
| `repositorio` | `captura`, `alt`, and `legenda` for the GitHub repository page. Current asset: `presentation/github/repositorio.png`, the supplied original preserved byte for byte. An empty value still receives a defensive placeholder. |
| `publicacao` | `commit` is the full SHA of `origin/main` used for code links (currently `c95bf7cb09de2eba1fff95b2d8cd94f809703718`, the merge of PR #13); `rotulo` is its label (“main · PR #13”). |
| `criterios` | Completeness criteria, shown in a dialog. |
| `itens[]` | Each journey: `resumo`, `fluxo` (three short labels), `jornada` (detailed steps), `evidencias`, `testes`, and `validacao`. |
| `evidencias[]` | Explicit catalog of files: `tipo` (`controller`, `model`, `view`, `service`, or `policy`), `caminho`, `papel`, `publicado`, and optional `captura`. |
| `extras` | Other parts of the system, each with `nome`, `estado`, and `nota`. |

`caminho` must be a relative path under `app/`, `config/`, `db/`, `lib/`, or `spec/`, without `..`. `publicado: true` means the file exists in the `publicacao.commit` commit, and the dialog links to `https://github.com/<repository>/blob/<sha>/<path>`. All current entries have `publicado: true` against that snapshot. For files not present in that snapshot, retain `publicado: false`: the dialog keeps the relative path and optional screenshot but provides no published GitHub link. It does not show a local-copy notice. Never set the flag to true unless the actual snapshot contains the file. The server never reads files from URL parameters; only this catalog is displayed.

**Ver implementação** opens a modal `<dialog>`. Focus moves to its title, Esc closes it, and focus returns to the button. Arrow keys do not change slides while it is open, and long content scrolls inside the dialog. The buttons also carry `commandfor` and `command="show-modal"`, so modern browsers open the dialog without JavaScript.

The GitHub capture is already configured at `app/assets/images/presentation/github/repositorio.png`; keep its original content. To add a code capture, save it in the same folder (for example, `app/assets/images/presentation/github/alerts-controller.png`) and set `captura` on that evidence.

When new code is merged into `main`, update `publicacao.commit` and every `publicado` flag. `spec/models/presentation_spec.rb` checks the flags against Git when the commit exists locally.

## Evolution and planning

`evolucao.yml` → `marcos` now contains eleven milestones in chronological order. The evolution slide begins at the historical first landing rather than filtering out events before the first delivery.

| Date | Milestone | Evidence boundary |
| --- | --- | --- |
| 14/09/2026 | Landing and SGU identity | Historical landing commit. |
| 23/09/2026 | First delivery | Delivery event from the academic schedule. |
| ≈ 30/09/2026 | Updated use cases | Explicitly estimated, because the actual update date is not recorded. |
| 01/10/2026 | Web presentation | Initial navigable presentation commit. |
| 02/10/2026 | Data model and migration | Source commit for the database work. |
| 02/10/2026 | Conceptual model | Source commit for the conceptual work. |
| 03/10/2026 | Occurrences, handling, and mural | First operational journey, expanded on 04/10. |
| 03/10/2026 | Alignment meeting | Actual meeting record and four originals. |
| 04/10/2026 | Retrospective and planning | Retrospective evidence and planning update; this does not establish the actual date of the retrospective session. |
| 04/10/2026 | Brand and logo | Identity source commit. |
| 04/10/2026 | Second delivery on the web | Revised presentation and evidence. |

Commit/source references stay in configuration for maintenance and are not buttons on timeline cards. `estimada: true` and `nota_data` make the use-case date visibly approximate, including accessible text. Do not replace that estimate with a claim of verified completion date. Leadership reports the use-case diagram complete; its actual image and metadata still need attaching to display the separate diagram slide.

`planejamento.yml` → `marco.captura` uses the supplied originals `presentation/mural/post-escuro.png` and `post-claro.png`. The dark path is `imagem`; the light path is `claro.imagem`, with alternative text for each. Screen and PDF both select the active theme. These captures demonstrate the mural, not a deployment.

`proximos_passos` lists five future priorities: map requirements/progress, integrate `letter_opener` for local email previews, create official UFRPE location seeds, refine bugs/design/usability, and simplify participation with persuasive design inspired by Instagram. The last priority aims to make publishing/following easier and encourage campus participation; existing likes alone do not establish a gamification system. `letter_opener` remains uninstalled and official location seeds are not created. Email confirmation remains unimplemented. No dates or owners are recorded.

## Meeting record and image gallery

Meeting records remain in `gestao.yml` → `reunioes`; the stable selection keys are still `reunioes` and `reunioes.registros`.

| Field | Meaning |
| --- | --- |
| `data`, `horario`, `tipo`, `plataforma` | Actual date, approximate or recorded time, meeting type, and meeting platform. Do not infer duration from screenshots. |
| `participantes`, `participantes_nota` | Known participant names and limits of that evidence, such as a truncated display name. |
| `pauta` | Discussion topics supported by the meeting record. |
| `decisoes`, `nota` | Recorded decisions and any remaining follow-up; keep an empty list when no decisions have been formalized. |
| `evidencias` | Gallery entries, each containing an asset `imagem`, visible `legenda`, and descriptive `alt`. Order controls thumbnails and print. |
| `evidencia_principal` | Initial featured asset, matched against `evidencias[].imagem`; absent or unmatched values use the first entry. Current value ends in `03-rails.png`. |
| `evidencia_imagem`, `evidencia_url` | Compatible legacy single-image and public-link fields; existing records do not need conversion. |

Image paths are relative to `app/assets/images`. The current four assets are:

- `presentation/reunioes/2026-10-03/01-painel.png`
- `presentation/reunioes/2026-10-03/02-administracao.png`
- `presentation/reunioes/2026-10-03/03-rails.png`
- `presentation/reunioes/2026-10-03/04-ambiente.png`

The copied originals remain unchanged. `app/views/presentations/slides/_reunioes.html.erb` uses `shared/_meeting_gallery.html.erb` and `app/javascript/controllers/meeting_gallery_controller.js`: one featured capture, a thumbnail strip, previous/next controls, and a live position count. ArrowLeft/ArrowRight/Home/End operate the strip and do not navigate slides. Images still open in the presentation lightbox; Esc closes it and restores focus. Without JavaScript, original image links remain available.

Print excludes navigation and the featured duplicate, rendering all four originals with captions through the shared figure component. The gallery's initial image does not determine which images appear in the PDF. Recheck page fit after adding meetings or longer text. Earlier gallery/export and integrated metrics are historical; the current refinement and its final validation belong in [the refinement review](../../docs/apresentacao-refinamento-revisao.md). The meeting date remains 03/10/2026.

The meeting captures are a faithful historical record of the version demonstrated on 03/10/2026. The visual-concept captures were regenerated later, on 04/10/2026, in both themes with the new brand; see [Visual concept captures](#visual-concept-captures).

## HTML/CSS diagrams and technology cards

DER, conceptual model, and architecture use `_er_diagram.html.erb` and `PresentationDiagram`. Entities, columns, relationships, and coordinates come from the catalog; row counts affect height and paths are calculated by the model. The DER displays `db/schema.rb`'s version. Update `tables`, `foreign_keys`, and relevant views in `data_diagrams.yml` after migrations; operational/social/infrastructure appendices should cover all columns. FK `required`/`unique` define cardinalities; polymorphic relationships are dashed entries in `relations`.

The conceptual diagram (`diagrams.conceptual`) is laid out wide, at 1350×580, with the same 11 concepts and 20 relations. Two options control it: `ports: distributed` places one port per connection along each side of a concept, and `cardinality_labels: true` draws the multiplicities at both ends of each relation. Its `notes` list is rendered under “Relações e cardinalidades”; the former “Dimensões distintas” box is now one of these notes. The physical DERs are unchanged.

`presentation_profiles` belongs to infrastructure, not an invented SGU business concept. Selecting an entity highlights connections and cardinalities; **Ampliar** keeps the interaction. Mobile diagrams use internal scrolling. Styles are organized under `app/assets/stylesheets/presentation/`, imported by `presentation.css`; review print after changing positions.

The conceptual slide shows `producao` and `premissas` under **Diagrama produzido** and **Regras do modelo**. The latter describes implemented rules: optional photos, ordinary internal posts, restricted panic/operational data, and external visibility subject to verification/moderation. It does not show a team-review badge. The conceptual model was produced in card #6; revise it instead of creating a duplicate. Keep version, origin, and date accurate. Team-supplied images belong in `app/assets/images/presentation/` with paths relative to `app/assets/images`. Pending use-case/flow images may use PNG/SVG; existing native diagrams stay HTML/CSS. Only public HTTP(S) URLs become links; filesystem paths are rendered as text.

The SGU logo is rendered by `sgu_brand(layout, tone:)` in `app/helpers/brand_helper.rb`. Layouts are `:symbol`, `:horizontal`, and `:vertical`. Tones are `:auto` (follows the page theme), `:on_light`, `:on_dark`, and `:dark_surface` (negative on screen, standard version in print). The existing logo files remain in `app/assets/images/brand/`; this refinement does not redesign them. The cover uses the horizontal layout. Cover, planning, and closing follow the selected theme; print preserves it. See the main [README](../../README.md#brand).

Technology cards use local logos or a neutral symbol; assets are in `app/assets/images/presentation/logos/`, with sources/conditions in `tecnologias.yml`. A neutral symbol is not a brand logo. With **Versões** selected inside **Tecnologias utilizadas**, mouse hover or keyboard focus shows a tooltip, Esc closes it, and **Mostrar versões** expands data below all cards. Disabling the content hides tooltips/data/control. Printing and no-JavaScript mode show selected versions even when collapsed on screen.

Version `rotulo` uses `gem`, `ruby_version_file: true`, `sqlite_engine: true`, or explanatory `texto`. Integration gem versions do not imply underlying technology versions: Tailwind separates Rails integration from CLI; SQLite separates Ruby adapter from database engine.

## Presentation timer and public access

The timer starts **paused at 07:00**; opening the presentation never starts it automatically. Use **Iniciar contador**, **Pausar contador**, **Resetar contador**, or **Modificar tempo**. Editing accepts whole minutes from **1 to 120**; applying a duration resets the countdown and leaves it paused. Reset uses the configured duration. The countdown uses a deadline and `Date.now()`, so background-tab throttling does not accumulate interval drift. Reloading initializes a new paused timer; this is not a saved profile setting. Timer controls are excluded from PDF.

The public index and customization panel show slide titles and selections without per-slide times or total estimates. Historical timing metadata remains available internally. The implementation is `app/javascript/controllers/presentation_timer_controller.js` with `shared/_timer.html.erb`.

The QR code on the cover and navigation opens the public presentation. Configure both `entrega.yml` → `links.apresentacao` (the full public URL, including `#s-capa`) and `links.qr_code` (asset path relative to `app/assets/images`). Current PNG: `presentation/acesso/apresentacao-qr.png`. The public presentation address is `https://sgu.lucasact4.com.br/apresentacao#s-capa`; `https://lucasact4.com.br/` remains routed to the application. This Cloudflare Tunnel exposes the local development application for demos. The subdomain DNS CNAME, tunnel ingress, Rails allowed host, and configured presentation URL are in place. On **2026-10-19**, the coordinator confirmed HTTP 200 over HTTPS for `/`, `/up`, and `/apresentacao` on both hosts and decoded the served QR PNG to the exact subdomain URL. See [Cloudflare startup and checks](../../docs/cloudflare-tunnel.md#normal-startup-and-checks).

Changing the public address requires updating `links.apresentacao` **and regenerating the PNG with the exact same URL**:

```bash
python3 script/gerar_qr_apresentacao.py 'https://sgu.lucasact4.com.br/apresentacao#s-capa'
```

Run the command from the repository root. Optional `--output arquivo.png` changes the destination; the default is `app/assets/images/presentation/acesso/apresentacao-qr.png`. The generator uses high error correction (H) and centers the existing `app/assets/images/brand/sgu-simbolo.png` on a white badge by default; no branding option is required. Python, `qrcode`, and Pillow are required only for regeneration, not Rails runtime. QA used `qrcode` and `zxing-cpp` under `tmp/qa_dependencies`; decoding is a verification step, not a runtime Rails dependency. Earlier byte-for-byte reproduction and PDF raster decoding results apply to the previous QR. The current served PNG and local branded PNG at 784, 328, 240, and 180 pixels decoded to the exact subdomain URL, including `#s-capa`. Physical-phone scanning and QR raster decoding from the new PDF were not tested. See [dated public verification](../../docs/apresentacao-refinamento-revisao.md#19102026--public-subdomain-verification) for asset, request/QR spec, and public PDF checks.

Regenerate and replace previously exported PDFs and printed QR codes containing the old ngrok or root-domain address; changing the source URL and PNG does not update existing copies.

`presentation_public_asset_url` derives **Abrir imagem** URLs from the public presentation address so exported image links do not point to the Selenium container. Those links open in a new tab with `noopener noreferrer`. Update the public URL before PDF export and confirm external access while the tunnel is running.

## Run and export PDF

Use `bin/dev` in the Dev Container and open `http://localhost:3000/apresentacao`. Avoid starting a second copy if it is already running; inspect the VS Code **Ports** forwarding when another project uses the same host port.

The presenting-mode layout target is a 1920×1080 viewport with the default second-delivery selection. `spec/features/presentation_revision_spec.rb` checks slide fit and mobile width. The earlier brand revision recorded some vertical scrolling in a shorter browser window; use **F** for full screen and check the actual projector/browser dimensions. Consult [the refinement review](../../docs/apresentacao-refinamento-revisao.md) for current measured results rather than assuming earlier measurements validate these changes.

Use **Baixar PDF** to download the current selection and theme directly, including selected appendices, without opening the browser print dialog. While **Gerando PDF…** is shown, wait for the download; errors appear beside the button and allow retrying.

The downloaded PDF starts with a separate full-page access QR before the cover: a centered 168mm square branded QR and links to the configured public presentation URL. This intro has no folio and is excluded from slide numbering; the ten main slides remain **01/10–10/10**. Ten main slides plus four appendices produce **15 pages** including the intro; a minimal cover/closing selection produces **three pages**. These changes apply only to downloaded PDFs; the website layout and navigation remain unchanged.

The PDF uses A4 landscape with 10mm top/bottom and 12mm side page margins. Main-slide text automatically enlarges to fit the physical printable area, with a three-column timeline and more room for figures. Appendices retain their existing typography. Any remaining overflow is scaled to fit. Public image/code links and internal appendix destinations remain clickable. Controls, maintenance notes, dialogs, and information buttons are omitted; compact evidence lines and short partial-item notes remain.

For this PDF refinement, coordinator checks passed **26 targeted request/browser examples, 0 failures**, and RuboCop reported **2 files, 0 offenses**. Dark/light exports each have **15 pages** and **42 annotation links, including 9 internal links**; the minimal selection has **3 pages**. Measurements found no child content outside printable bounds in either theme. The coordinator visually reviewed the final Poppler renders in both themes and decoded each rendered intro QR to the configured subdomain URL. The updated PDF downloaded over public HTTPS with HTTP 200; its links contain no ngrok or local renderer addresses.

The download posts to `/apresentacao/pdf` with CSRF protection. [`Presentation::Pdf`](../../app/services/presentation/pdf.rb) renders the server's presentation HTML with styles and images embedded, so the renderer does not need to open the public domain or another Rails URL. The Dev Container supplies Chromium through `SELENIUM_REMOTE_URL=http://selenium:4444/wd/hub`; keep its Selenium service available. Outside that environment, configure a reachable Selenium Chrome service or provide local Chrome/Chromium and the dependencies/permissions needed by Selenium Manager. `selenium-webdriver` is a runtime dependency, but the production Dockerfile does not install Chromium or provision a renderer; configure one before offering PDF downloads in production. Overlapping exports in the same Rails process return a retryable busy response.

Ctrl+P remains available for manual browser printing. Select A4 landscape, enable background graphics, and review the preview; this path uses the website's print layout without the download-only QR intro or automatic slide fitting.

The existing command-line Selenium exporter is a separate workflow for saved profiles. It opens a presentation URL and uses the website's print layout without the download-only QR intro or automatic fitting. It does not receive temporary choices from another browser tab. Run an additional presentation server in a separate Dev Container terminal:

```bash
RAILS_DEVELOPMENT_HOSTS=rails-app bin/rails server -b 0.0.0.0 -p 3100 -P tmp/pids/apresentacao-3100.pid
```

With Selenium active, run:

```bash
APRESENTACAO_TEMA=dark bundle exec ruby script/exportar_apresentacao_pdf.rb tmp/apresentacao/sgu-atual-escuro.pdf
APRESENTACAO_TEMA=light bundle exec ruby script/exportar_apresentacao_pdf.rb tmp/apresentacao/sgu-atual-claro.pdf
```

The script reads `http://rails-app:3100/apresentacao?modo=leitura`. `APRESENTACAO_TEMA` accepts `dark` (default) or `light`; any other value is rejected. A destination argument is optional and defaults to `tmp/apresentacao/sgu-segunda-entrega.pdf`. `localhost` inside Selenium is not the Rails container. Confirm forwarded ports 3000/3100 and stop only the additional server with Ctrl+C after export.

The script loads a new page with the active profile, ignoring temporary selections from another tab. For a saved profile:

```bash
APRESENTACAO_URL="http://rails-app:3100/apresentacao?modo=leitura&perfil=<id>" APRESENTACAO_TEMA=dark bundle exec ruby script/exportar_apresentacao_pdf.rb tmp/apresentacao/sgu-atual-escuro.pdf
APRESENTACAO_URL="http://rails-app:3100/apresentacao?modo=leitura&perfil=<id>" APRESENTACAO_TEMA=light bundle exec ruby script/exportar_apresentacao_pdf.rb tmp/apresentacao/sgu-atual-claro.pdf
```

Replace `<id>` using administration's **Visualizar** link. The Dev Container defaults `SELENIUM_REMOTE_URL` to `http://selenium:4444/wd/hub`; a different host must be reachable by Selenium and allowed by Rails. Inspect every PDF page, images, clipping, diagrams, text, and links. `tmp/` is ignored by Git; share the final PDF explicitly.

## Validation

The earlier integrated run after the native appendix-link correction passed **731 examples, 0 failures**, seed **65244**, in **4 min 24.5 sec**, with **97.15%** line coverage (4,270/4,395); log: `tmp/qa_final_verified.log`. RuboCop checked **319 files without offenses**; Zeitwerk, Brakeman (no warnings), Tailwind, JavaScript syntax, and `git diff --check` passed. Visual checks include 20 Full HD captures and all ten main slides at 320×568, 390×844, 768×1024, and 1366×768 in both themes without horizontal overflow. Both themed PDFs have **14 reviewed pages**, **31 public HTTP(S) links**, and **nine valid internal destinations** each, with no localhost/container-host links. The cover QR was decoded from both PDF rasters. The native appendix-link correction also passed **two targeted request/browser examples, zero failures**. These results predate the direct-download endpoint and the branded subdomain QR migration. The preceding 730/0 and 726/0 runs remain previous validations; see [the refinement review](../../docs/apresentacao-refinamento-revisao.md) for both phases and evidence boundaries.

Focused direct-download checks cover transient selections, profile preservation, attachment responses, renderer failures, busy responses, button progress, and retry messages:

```bash
bundle exec rspec spec/requests/presentation_pdf_request_spec.rb spec/features/presentation_pdf_spec.rb
```

The request specs stub the renderer and the browser specs stub its response. Also download a real PDF and inspect its page count, padding, dense slides, theme images, external links, and internal destinations when changing rendering or print styles.

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

These checks cover catalog keys, images/links, saved selection, administration restrictions, navigation, customization, print, requirement titles, and DER agreement with the test schema. Navigation tests include technology tooltips/mobile expansion and real script export with loaded logos. `presentation_meeting_spec.rb` verifies the four originals, lightbox focus restoration, mobile layout, and a three-page meeting-only export; it restores the viewport after capturing. `presentation_revision_spec.rb` measures the 1920×1080 layout target and phone width without horizontal scrolling, and checks theme-dependent captures, timer/QR/index controls, the evidence dialog, popovers, conceptual multiplicities, and themed printing without dialogs. Automated tests do not verify the teacher's external-link access or establish actual speaking duration. Read the PDF, check links without the team's session, and rehearse.

See [the earlier presentation review](../../docs/presentation-upgrade-review.md) for its dated handoff and [the current occurrence/social guide](../../docs/occurrence-social-flow.md) for application rules and validation. The [presentation and brand review](../../docs/apresentacao-identidade-sgu-revisao.md) records the previous revision, including its 720-example run with one failure; it remains historical. Current refinement results are in [the refinement review](../../docs/apresentacao-refinamento-revisao.md). Existing alerts without a post are not silently disclosed by visiting their detail: the author must confirm an audience before the new mural creates that legacy record's publication. See the occurrence/social guide for that compatibility boundary.
