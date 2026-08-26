# Nyika Community Registry

A household registry for Nyika village. The guiding principle is
**one identity, many programmes, one auditable history**: a household is registered
once, and later programmes, campaigns and contributions attach to that single
record over time, with a full audit trail.

This repository is the **registry core** — the foundation later modules attach to.

## Scope

In scope: Household / Person / ConsentRecord, an immutable audit trail, the
verification queue (draft → pending → verified), role-based access, the registrar
workspace, assisted capture, the resident update link, and the pilot exports and
data-quality report.

Out of scope for now, and deliberately so: the programme case workflow, the
mobilisation ledger, payment reconciliation, WhatsApp/SMS/USSD messaging, plot
records and political contribution flows. The last two are excluded by the brief
itself, not merely deferred.

## Governance rules

These are structural, not policy notes. Changes that break them are defects, and
`test/models/governance_test.rb` fails when one is broken.

- **Field minimisation.** No national ID, health, income, disability specifics, or
  plot claims anywhere in the schema. Use `age_band` / `year_of_birth`, never a
  full date of birth; `location_description`, never GPS or plot title.
- **Purpose-specific consent.** Consent is one row per purpose — village
  administration, communication, programme support, payment receipts and partner
  contact — carrying version, channel and withdrawal status. Never a single
  blanket flag. Withdrawal is recorded; the row is never deleted.
- **Immutable audit.** Every sensitive change records actor, timestamp, old value,
  new value, reason **and source channel**. Records are never destroyed —
  soft-delete or status change only.
- **Role-based access.** Enforced through a single CanCanCan `Ability` class
  against the `role` on the user. A registrar cannot verify their own capture;
  verification is a second pair of eyes.

## How residents use it

Residents have **no accounts and no passwords**. Each household has an unguessable
link (`/h/<token>`) that opens its own record for updating. In this build a
registrar copies that link from the household's admin page and sends it by hand;
when the messaging work lands it will send the same link by WhatsApp or SMS.

The link is a **bearer credential** — anyone holding it can edit that household —
so "Regenerate resident link" on the household page revokes it immediately.

A resident's change never goes live unchallenged: it returns the household to the
verification queue, and is recorded in the audit trail against the household with
source channel `resident_link`. That channel is also what makes the pilot's
"residents who can update without assistance" metric measurable.

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
npm run build:css      # compiles BOTH stylesheets
cp .env.example .env
bin/rails db:create db:migrate db:seed
bin/rails server
```

| where | what |
|---|---|
| `/` | public landing page — shows no registry data |
| `/admin` | registrar and administrator workspace |
| `/capture/households/new` | assisted capture, mobile-first, signed in |
| `/h/<token>` | a household's own record, no account needed |
| `/admin/data_quality` | pilot metrics and the data-quality report |

Seeded logins are `registrar@`, `admin@`, `programme@` and `tech@nyika.local`
with the password `nyika-dev-password` (override with `SEED_PASSWORD`).

### The CSS build step

There are **two** Tailwind entry points in `app/assets/tailwind/`:
`active_admin.css` for the admin, and `application.css` for the resident and
capture pages. `npm run build:css` builds both into the gitignored
`app/assets/builds/`.

ActiveAdmin 4 styles itself with Tailwind v4 through an npm plugin and ships no
precompiled CSS, so this is not optional — without it the admin raises
`Propshaft::MissingAssetError`. Tailwind only emits the utility classes it finds
in your source, so **rebuild after changing anything under `app/admin/` or
`app/views/`**:

```bash
npm run build:css
```

The Tailwind sources are excluded from the asset load path so Propshaft serves
the compiled files rather than the raw `@import`.

## Programme cases

One government-support workflow, following the deck's five stages: identify →
consent → evidence → submit → outcome. Programme types are BEAM, drought relief,
disability support and other support.

A case **cannot be submitted** until three things are true, and the case screen
lists whichever are outstanding:

1. everyone it covers has consented to `programme` — the consent model gating
   something real, not a box ticked once;
2. every required document for that programme has been sighted **and verified by
   someone other than whoever recorded it**;
3. the household itself has been verified.

Eligibility checks are **prompts, not refusals**. The platform supports
applications and records outcomes; it does not replace government decision
authority, so a case with eligibility queries can still proceed.

### Sensitive data

The brief permits health, disability, children and financial data inside a
programme case with restricted access. **This build captures none of it.** A case
records that a document was sighted, of what type, by whom, and where it is
stored — never what it contained. `test/models/governance_test.rb` covers the case
models too, so that stays true by accident-proofing rather than good intentions.

Document records hold **metadata and a link only**. No files are uploaded, and
identity document images are never stored.

### Who can see casework

A **registrar cannot see programme cases at all** — not the screens, not the CSV,
not the dashboard panels, not even the menu items. A case reveals that a family
sought welfare support, which is exactly the kind of thing that must not circulate
around a village. Administrators and programme managers run casework; a tech admin
can administer cases but deliberately cannot submit one or decide an outcome.

## Mobilisation and payments

Campaigns raise money, materials or labour. **The platform never holds funds** —
money moves on a licensed rail (EcoCash, InnBucks, bank) or to an authorised cash
collector, and the registry records where it was meant to go and matches it
afterwards. The registry orchestrates and reconciles; it is not a bank.

Four rules do the work:

1. **A campaign cannot open without an approved receiving account or collector.**
   This is the mitigation for the brief's "payment confusion" risk — residents
   paying the wrong account.
2. **A contribution is only reconciled against a VERIFIED receipt**, and whoever
   captured a receipt cannot verify it. Whoever takes the money is never the
   person who confirms it arrived.
3. **A receipt that does not match the pledge is refused**, not quietly accepted.
   It goes to the exception queue with a note, which is what fills the finance
   exception report.
4. **Cash receipts must carry proof** — a link to banking proof or a photographed
   slip. Cash is where money goes missing.

Materials and labour are **counted, never priced**. Putting a cash value on
someone's donated labour is a judgement the registry has no business making.

Residents are told whether a campaign is `voluntary` or an `approved_obligation`.
Being asked and being required are different things.

### The political firewall

Both documents forbid mixing contribution flows with welfare, vulnerability or
government programme data. That is enforced structurally, not by good intentions:

- **There is no association between `Contribution` and `ProgrammeCase`**, in
  either direction, and no foreign key joining them. A governance test fails if
  one is added.
- **A registrar cannot see casework. A programme manager cannot see money.**
  Neither can form the link "this family gave, or did not give, so treat their
  support claim accordingly". Only an administrator sees both, and they are the
  accountable owner.
- **Political fundraising is not an available campaign type.** It is excluded
  until legal and governance approvals are explicit, so the option is absent
  rather than present-and-discouraged.

## Reports

```bash
bin/rails pilot:report    # data quality and pilot metrics on stdout
bin/rails pilot:export    # the same as CSV (PILOT_CSV=path)
```

The same numbers appear at `/admin/data_quality`, and each admin resource exports
CSV. `PilotReport` is the single source for all three so they cannot drift apart.

The household CSV **omits the resident token deliberately**: exports get mailed
around, and every token in one is a working key to that household.

## Deploying

`render.yaml` is a Render blueprint: **New -> Blueprint -> pick this repository**.
It provisions a free web service (built from the `Dockerfile`) and a free Postgres.

Neither declares a region, so both take Render's default and are guaranteed to
match. That matters: Render's internal database hostname resolves only within a
single region, and a mismatch fails at boot with
`PG::ConnectionBad: could not translate host name "dpg-..."`. If you pin a region,
pin it on both.

Two values must be set by hand in the Render dashboard — neither is in the repo:

| variable | where it comes from |
|---|---|
| `RAILS_MASTER_KEY` | the contents of your local `config/master.key` |
| `SEED_PASSWORD` | choose one. **Required:** this repository is public, so the fallback in `db/seeds.rb` is readable by anyone |

`bin/docker-entrypoint` runs `rails db:prepare` and then `rails db:seed` on every
boot. `db:prepare` only seeds when it *creates* the database, so without the
explicit `db:seed` a database that already exists would never get its users.

> **Before this holds real household data, remove `db:seed` from
> `bin/docker-entrypoint`.** Seeding on boot resets the demo passwords on every
> deploy. That is a demo affordance and nothing more.

The `Dockerfile` installs Node **in the build stage only**, to compile the two
Tailwind stylesheets. The runtime image ships the compiled CSS and no JavaScript
toolchain. Without that step the admin screens raise
`Propshaft::MissingAssetError` in production.

Free-tier caveats worth knowing before sharing a link: the web service sleeps after
inactivity, so the first request can take the better part of a minute, and free
Postgres instances expire after a limited period. Check Render's current terms.

## Known limitations

Worth stating plainly rather than discovering later:

- **The resident link is a bearer credential.** Anyone holding it can edit that
  household. That is the accepted cost of access without accounts, and it mirrors
  how a WhatsApp link behaves. Regenerate a link that goes astray.
- **The resident endpoint is public and unrated.** The token is unguessable, but
  `/h/<token>` accepts requests from anyone. Rate limiting is worth adding before
  a real pilot.
- **No messaging.** Links are copied and sent by hand until the WhatsApp/SMS work
  package lands.
- **Consent wording is a placeholder.** `ConsentRecord::CURRENT_VERSION` is `v1`
  and the descriptions are drafts. Real wording needs review before capture
  begins — consent that is not understood is not consent.
- **Seeding on boot** (see Deploying) must be removed before real data.

## Notes

- Ruby and Node are managed with asdf; both are pinned in `.tool-versions`.
- Use `bin/rails`, not a global `rails` — the binstub uses the bundled gems.
- ActiveAdmin is pinned to `4.0.0.beta22`. Version 4 is still a beta, but it is the
  only line that supports Rails 8 + Propshaft; ActiveAdmin 3.x requires Sprockets
  and jQuery. The npm package must stay on the matching `4.0.0-beta22`, since the
  stable npm `latest` tag still points at the 3.x-era package.
