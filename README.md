# Nyika Community Registry

A household registry for Nyika village. The guiding principle is
**one identity, many programmes, one auditable history**: a household is registered
once, and later programmes, campaigns and contributions attach to that single
record over time, with a full audit trail.

This repository is the **registry core** — the foundation later modules attach to.

## Scope

In scope: Household / Person / ConsentRecord, an immutable audit trail, the
verification queue (draft → pending → verified), role-based access, the
registrar workspace, an assisted capture form, and CSV exports.

Out of scope for now: programme case workflow, mobilisation ledger, payment
reconciliation, WhatsApp/SMS/USSD, plot records.

## Governance rules

These are structural, not policy notes. Changes that break them are defects.

- **Field minimisation.** No national ID, health, income, disability specifics, or
  plot claims anywhere in the schema. Use `age_band` / `year_of_birth`, never a
  full date of birth; `location_description`, never GPS or plot title.
- **Purpose-specific consent.** Consent is one row per purpose, carrying version,
  channel and withdrawal status. Never a single blanket flag.
- **Immutable audit.** Every sensitive change records actor, timestamp, old value,
  new value and reason. Records are never destroyed — soft-delete or status change
  only.
- **Role-based access.** Enforced through a single CanCanCan `Ability` class
  against the `role` on the user.

## Stack

Ruby on Rails 8.1 + PostgreSQL, with ActiveAdmin (registrar workspace),
Devise (authentication), PaperTrail (audit trail), CanCanCan (authorisation),
and Hotwire/Turbo for the resident-facing forms.

## Setup

Requires PostgreSQL running, plus Ruby 3.3.8 and Node 22.15.0 — both pinned in
`.tool-versions`, so asdf selects them automatically inside this directory.

```bash
bundle install
npm install            # ActiveAdmin 4's Tailwind plugin
npm run build:css      # compiles app/assets/builds/active_admin.css
cp .env.example .env
bin/rails db:create db:migrate db:seed
bin/rails server
```

The registrar workspace is at `/admin`.

### The CSS build step

ActiveAdmin 4 styles itself with Tailwind v4 through an npm plugin, and ships no
precompiled CSS. `app/assets/builds/active_admin.css` is generated, gitignored, and
**must be rebuilt after changing anything under `app/admin/`** — Tailwind only emits
the utility classes it finds in your source:

```bash
npm run build:css
```

Without it the admin screens render unstyled. The Tailwind source lives in
`app/assets/tailwind/`, which is excluded from the asset load path so Propshaft
serves the compiled file instead of the raw `@import`.

## Deploying

`render.yaml` is a Render blueprint: **New -> Blueprint -> pick this repository**.
It provisions a free web service (built from the `Dockerfile`) and a free Postgres.

Two values must be set by hand in the Render dashboard — neither is in the repo:

| variable | where it comes from |
|---|---|
| `RAILS_MASTER_KEY` | the contents of your local `config/master.key` |
| `SEED_PASSWORD` | choose one. **Required:** this repository is public, so the fallback in `db/seeds.rb` is readable by anyone |

The database is prepared automatically on first boot: `bin/docker-entrypoint` runs
`rails db:prepare`, which loads the schema and runs the seeds when the database is
new, then only runs pending migrations on later deploys.

The `Dockerfile` installs Node **in the build stage only**, to compile
ActiveAdmin's Tailwind CSS. The runtime image ships the compiled stylesheet and no
JavaScript toolchain. Without that step the admin screens raise
`Propshaft::MissingAssetError` in production.

Free-tier caveats worth knowing before sharing a link: the web service sleeps after
inactivity, so the first request can take the better part of a minute, and free
Postgres instances expire after a limited period. Check Render's current terms.

## Notes

- Ruby and Node are managed with asdf; both are pinned in `.tool-versions`.
- Use `bin/rails`, not a global `rails` — the binstub uses the bundled gems.
- ActiveAdmin is pinned to `4.0.0.beta22`. Version 4 is still a beta, but it is the
  only line that supports Rails 8 + Propshaft; ActiveAdmin 3.x requires Sprockets
  and jQuery. The npm package must stay on the matching `4.0.0-beta22`, since the
  stable npm `latest` tag still points at the 3.x-era package.
