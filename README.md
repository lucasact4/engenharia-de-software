<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="app/assets/images/brand/sgu-logo-horizontal-negativo.png">
    <img src="app/assets/images/brand/sgu-logo-horizontal.png" alt="SGU" height="76">
  </picture>
</p>

<h1 align="center">SGU — Sistema de Gerenciamento Urbano</h1>

<p align="center">Communication and follow-up of occurrences on the UFRPE campus.</p>

<p align="center">
  Software Engineering course (Engenharia de Software) · Universidade Federal Rural de Pernambuco (UFRPE)<br>
  Equipe UFRPE de Engenharia de Software · Academic project; not an official UFRPE service.
</p>

## Contents

- [Features](#features)
- [Technologies](#technologies)
- [Getting started](#getting-started)
- [Local access](#local-access)
- [Tests and quality](#tests-and-quality)
- [Documentation](#documentation)
- [Brand](#brand)
- [Infrastructure and deployment](#infrastructure-and-deployment)
- [License and credits](#license-and-credits)

## Features

- **Occurrence registration:** title, description, category, severity, and photos with a chosen cover and order. Location by GPS, a point on the map, or a campus location.
- **Handling and follow-up:** coordination assesses, assigns, and resolves occurrences. The author follows the status but does not see internal notes.
- **Social board (mural):** comments, replies, likes, saves, and follows.
- **Public posts:** verified authors publish directly. Posts from other authors go through approval of the same post, and a rejection requires a reason.
- **Panic alert:** restricted registration. Its operation has not been institutionally validated yet.
- **Administration and moderation:** content reports, post withdrawal, comment removal, and an audit trail.
- **Registration:** requires an `@ufrpe.br` email and includes an account review. Email confirmation is **not** implemented yet.
- **Light and dark themes.** Dark is the default.
- **Academic presentation** at `/apresentacao`.

## Technologies

| Area | Tools |
| --- | --- |
| Language and framework | Ruby 3.4.8 (`.ruby-version`), Rails 8.1.3.1 |
| Data | SQLite, Solid Cache, Solid Queue, Solid Cable |
| Interface | Hotwire (Turbo, Stimulus), Importmap, Tailwind CSS, Preline, Lucide icons via `rails_icons` |
| Authorization and pagination | Pundit, Pagy |
| Files and images | Active Storage with `image_processing` and libvips |
| Maps | Leaflet (vendored in `vendor/javascript/leaflet.js`) with OpenStreetMap tiles |
| Tests | RSpec, Capybara, Selenium, FactoryBot, SimpleCov |
| Quality and security | RuboCop, Brakeman, GitHub Actions, Dependabot |
| Environments | Dev Container, Docker, Kamal |

The exact gem versions are listed in `Gemfile.lock`.

## Getting started

### First setup (Dev Container, recommended)

1. Open the project folder in VS Code with the **Dev Containers** extension.
2. Select **Reopen in Container**.
3. Wait for the `postCreateCommand` to finish. It runs `bin/setup --skip-server`, which installs gems with `bundle install`, runs `bin/rails db:prepare`, and clears logs and temporary files.

On a new database, `db:prepare` also runs the seeds, so the [demo accounts](#demo-accounts-development-only) become available.

The container includes a Selenium Chrome service named `selenium`. It is configured through `SELENIUM_REMOTE_URL=http://selenium:4444/wd/hub` in `.devcontainer/devcontainer.json` and `.devcontainer/compose.yaml`.

**Without the Dev Container**, install:

- the Ruby version in `.ruby-version`;
- Bundler;
- SQLite;
- libvips, which is needed for image variants;
- Google Chrome and Selenium, which are needed for JavaScript feature specs.

Then run `bin/setup --skip-server`. See [Local development](docs/development.md) for details.

### Start an environment that is already prepared

```bash
bin/dev
```

`bin/dev` runs `Procfile.dev`:

```text
web: bin/rails server -p 3000
css: bin/rails tailwindcss:watch
```

The application is available at <http://localhost:3000>.

### Update the database without losing data

After pulling changes or switching branches, apply pending migrations:

```bash
bin/rails db:migrate
```

Do not use `bin/rails db:reset` or `bin/rails rails_base:db:reset` for this. Both commands drop the local data.

Optional targeted tasks:

- `bin/rails sgu:catalogs:bootstrap` creates missing roles and categories. You can run it more than once. It does not change accounts, edited names, or deactivated items.
- `bin/rails sgu:presentation:profiles` creates missing presentation profiles. It does not overwrite profiles edited in the administration area.

Seeds (`bin/rails db:seed`, or `bin/rails rails_base:db:init`, which runs `db:create`, `db:migrate`, and `db:seed`) run both steps above. In development, they also **reset the demo accounts**: the passwords, the administrator flag, and the active status. Use the targeted tasks if you have changed those accounts.

### Rebuild CSS

```bash
bin/rails tailwindcss:build
```

Run this command before tests or screenshots. A long-running `bin/dev` watcher can keep an outdated build, so restart `bin/dev` after CSS changes.

## Local access

- After signing in, administrators land on `/admin` and other accounts land on their panel at `/painel`.
- The public board is at `/mural`.
- Public registration is at `/criar-conta`. It requires an email ending exactly in `@ufrpe.br` and a visitor, professor, or student profile.
- By default, new registrations are approved automatically. This default is not limited to development. To require approval, set `SGU_AUTO_APPROVE_REGISTRATIONS=false` before you start the application. Administrators review accounts at `/admin/cadastros`.
- The catalog of campus locations starts empty on purpose. Register only real, verified locations at `/admin/locais`.

### Demo accounts (development only)

| Email | Password | Access |
| --- | --- | --- |
| `test@test.com` | `test@123` | Regular account |
| `dev@dev.com` | `test@123` | Administrator |

These accounts exist only in development. Never use them in production. The `@ufrpe.br` requirement applies to public registration, so these existing accounts still work.

For routes, permissions, and flows, see the [occurrence and social guide](docs/alertas-crud-implementacao.md) (Portuguese). For registration limits and themes, see the [registration and themes guide](docs/sgu-cadastro-temas-revisao.md) (Portuguese).

## Tests and quality

Run these checks inside the Dev Container. They match the GitHub Actions workflow in `.github/workflows/ci.yml`.

```bash
bin/rubocop                   # code style
bin/brakeman --no-pager       # static security analysis
bin/importmap audit           # JavaScript dependency audit
bin/rails tailwindcss:build   # build CSS before tests
bundle exec rspec             # JavaScript feature specs need Selenium
```

### Run every check

```bash
bin/rubocop && \
  bin/brakeman --no-pager && \
  bin/importmap audit && \
  bin/rails tailwindcss:build && \
  bin/rails db:prepare && \
  bundle exec rspec
```

## Documentation

- [Bootstrap a new project](docs/bootstrap.md)
- [Credentials, environment variables, and email](docs/configuration.md)
- [Local development](docs/development.md), including [administrative CRUD generation](docs/development.md#creating-an-administrative-crud), [icons](docs/development.md#icons), and [dependency updates](docs/development.md#updating-dependencies-and-version)
- [Upgrading an existing database to the SGU data model](docs/data-model-upgrade.md)
- [Registration, themes, and review](docs/sgu-cadastro-temas-revisao.md) (Portuguese)
- [Occurrence posts, public review, and verification](docs/occurrence-social-flow.md)
- [Occurrences, handling, board, and social features: implementation](docs/alertas-crud-implementacao.md) (Portuguese)
- [SQLite in production](docs/sqlite-production.md)
- [Backing up and restoring SQLite production data](docs/sqlite-backup-and-restore.md)
- [Migrating from SQLite to PostgreSQL](docs/sqlite-to-postgresql.md)
- [First deployment checklist](docs/first-deploy.md)
- [Project delivery checklist](docs/project-delivery.md)
- [Renaming the base project](docs/renaming.md)
- [Presentation maintenance](config/presentation/LEIAME.md)
- [Review of the presentation and brand update](docs/apresentacao-identidade-sgu-revisao.md) and the [earlier presentation review](docs/presentation-upgrade-review.md) (Portuguese)

## Brand

The logo files are in `app/assets/images/brand/`:

- `sgu-simbolo.png`: the symbol only.
- `sgu-logo-horizontal.png`: the symbol with "SGU" beside it.
- `sgu-logo-vertical.png`: the symbol with "SGU" below it.

Files ending in `-negativo` are for dark backgrounds. Every file has an SVG source, and `sgu-marca-fonte.svg` is an editable artboard. To regenerate the files, run:

```bash
bundle exec ruby script/gerar_marca_sgu.rb
```

The lettering is drawn as geometric strokes, so no third-party font is used. The SGU mark belongs to this project. It is not the official UFRPE coat of arms.

## Infrastructure and deployment

- `Dockerfile` defines the production image.
- `config/deploy.yml` and `.kamal/secrets` hold the Kamal configuration and the names of the required secrets. The configuration still contains template placeholders.
- No SGU deployment has been recorded yet. Before you deploy, follow the [first deployment checklist](docs/first-deploy.md) and decide on a [SQLite backup strategy](docs/sqlite-backup-and-restore.md).

## License and credits

- This project started from a reusable Rails base. It is distributed under the MIT License in [`LICENSE`](LICENSE), which keeps the copyright notice of the original base.
- Leaflet is distributed under its own license, in [`vendor/javascript/leaflet.LICENSE`](vendor/javascript/leaflet.LICENSE).
- Map tiles and data © [OpenStreetMap](https://www.openstreetmap.org/copyright) contributors. The map displays this attribution.
