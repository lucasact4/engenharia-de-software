# Local Development

This guide describes the supported development environment for Rails Base. The recommended path is the VS Code Dev Container because it provides the same Ruby, SQLite, and browser-testing dependencies used by the project.

## Dev Container (recommended)

1. Install Docker and VS Code with the **Dev Containers** extension.
2. Open the project directory in VS Code.
3. Select **Reopen in Container**.
4. Wait for the post-create command to finish. It runs:

```bash
bin/setup --skip-server
```

The container exposes the application on port 3000 and provides a Selenium Chrome service for feature specs.

If dependencies, migrations, or configuration change, run the setup command again:

```bash
bin/setup --skip-server
```

## Manual setup

When a Dev Container is not available, install:

- the Ruby version declared in `.ruby-version`;
- Bundler;
- SQLite;
- Google Chrome and the browser-driver dependencies used by Selenium;
- build tools required by native gems.

Then run:

```bash
bin/setup --skip-server
```

Manual environments are not the primary support target, so prefer the container when browser tests or system libraries cause problems.

## Run the application

Start Rails and the Tailwind watcher together:

```bash
bin/dev
```

The application is available at `http://localhost:3000`. Administrators land on `/admin` after signing in; other accounts land on `/painel`.

To run only Rails:

```bash
bin/rails server
```

## Database and sample data

Prepare the database after pulling changes or switching branches:

```bash
bin/rails db:prepare
```

Reset local data only when it is safe to discard it:

```bash
bin/rails db:reset
```

`db:reset` also runs seeds. The project provides a development initialization task:

```bash
bin/rails rails_base:db:init
```

It creates, migrates, and seeds the local database. The seeded accounts are documented in the main [README](../README.md#demo-accounts-development-only).

Seeds also create the essential role and category catalogs in every environment; in development they additionally reset the demo accounts. To upgrade an existing database to the SGU data model, or to create catalogs without running seeds, see [Upgrading an existing database to the SGU data model](data-model-upgrade.md).

## Daily validation

Before opening a pull request, run the commands in [Tests and quality](../README.md#tests-and-quality). They match the checks required by GitHub Actions.

Useful focused commands:

```bash
bundle exec rspec spec/requests
bundle exec rspec spec/features
bin/rubocop -a
bin/brakeman --no-pager
```

Use `bin/rubocop -a` for safe automatic corrections. Use `bin/rubocop -A` only after reviewing the broader changes it may make.

## Common recovery steps

- Dependencies changed: run `bin/setup --skip-server`.
- A migration is pending: run `bin/rails db:prepare`.
- CSS changes are not updating: restart `bin/dev`.
- Feature specs cannot reach Chrome: reopen or rebuild the Dev Container, then rerun the specs.

## Creating an administrative CRUD

The project automatically configures the `my_scaffold_controller` generator, which creates controllers in the administrative area and their related test files.

### 1. Generate the entity

Use only the entity name, without a namespace:

```bash
bin/rails generate scaffold Bird name:string age:integer deleted_at:datetime:index
```

Avoid `admin/bird`: it creates namespaced models and factories and adds unnecessary maintenance. The command above generates, among other files:

- a migration and model;
- an `Admin` controller and helper;
- a Pundit policy;
- factory and model, policy, feature, request, helper, and routing specs.

### 2. Run the migration

```bash
bin/rails db:migrate
```

The generator normalizes the route into the administrative area:

```ruby
namespace :admin do
  resources :birds
end
```

### 3. Add translations

Add the entity name and its attributes in `config/locales/pt-BR.yml` and `config/locales/en.yml`:

```yml
# config/locales/pt-BR.yml
pt-br:
  birds:
    single: "Pássaro"
    plural: "Pássaros"
  activerecord:
    attributes:
      bird:
        name: "Nome"
        age: "Idade"
```

```yml
# config/locales/en.yml
en:
  birds:
    single: "Bird"
    plural: "Birds"
  activerecord:
    attributes:
      bird:
        name: "Name"
        age: "Age"
```

Sidebar labels use `birds.plural`; form and table fields use `activerecord.attributes.bird.<attribute>`.

### 4. Add the menu item

Edit `app/controllers/concerns/sidebar_concerns.rb`:

```ruby
{
  name: t("birds.plural"),
  icon: "bird",
  policy: :bird,
  url: { controller: "birds", action: "index" },
  active: controller_path == "admin/birds"
}
```

The policy must exist because the menu checks `policy(menu_item[:policy]).menu?` before rendering the item.

### 5. Review generated files

Before finishing, review the factory, policy, permitted parameters, feature specs, and translations. Feature templates include `#change_here` markers for form-specific adjustments.

## Icons

The project uses `rails_icons` with the Lucide library:

```erb
<%= icon "search", class: "size-4" %>
```

To add a single icon, download its SVG to the local library:

```bash
ICON=circle-check
curl -Ls "https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/${ICON}.svg" \
  -o "app/assets/svg/icons/lucide/outline/${ICON}.svg"
```

The icon preview is available at `/rails_icons`. To synchronize the entire Lucide library, run:

```bash
bin/rails generate rails_icons:sync --library=lucide
```

## Updating dependencies and version

To install the versions declared in the Gemfile:

```bash
bundle install
```

To update a specific dependency:

```bash
bundle update gem-name
```

### Dependabot pull request policy

Dependabot checks Bundler and GitHub Actions dependencies every Monday at 09:00 in the America/Sao_Paulo time zone. Each ecosystem can have up to five open Dependabot pull requests.

- Treat security updates as urgent: review and merge them on the same business day when the quality checks pass.
- Review non-security updates at least weekly. Close or defer a pull request only with a short explanation so that the remaining risk is visible.
- Dependabot groups patch and minor version updates per ecosystem. Review each group's release notes and compatibility impact before merging.
- Major version updates remain individual pull requests and require review of release notes and any Rails, Ruby, database, or deployment changes.
- Before merging, confirm the GitHub Actions security, lint, and test checks pass. For application dependencies, also run the [local quality checks](../README.md#tests-and-quality) when the change needs investigation.
- Do not merge an update simply because it is automated. Resolve failing checks, compatibility notes, and configuration changes in a dedicated follow-up pull request when they are outside the dependency update's scope.

To create a new semantic version, update `CHANGES`, and create a Git tag:

```bash
. bumpversion.sh
```
