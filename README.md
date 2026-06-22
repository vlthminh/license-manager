# License Manager

![CI](https://github.com/vlthminh/license-manager/actions/workflows/ci.yml/badge.svg)

A small floating-license seat manager, built as a code-review/architecture
demo: clean Rails API, explicit service objects, and tests that actually
prove the concurrency story rather than just the happy path.

## 1. Overview

A company buys `N` "seats" for a piece of software. Employees check out a
license seat to use it and check it back in when done. If all seats are
taken, a checkout request must be rejected safely — including when many
requests race in at the same time.

This domain was picked because it has a small but real concurrency problem
(seat counting under contention) that's easy to get subtly wrong with
naive `count` + `if` logic, and gives a natural place to show pessimistic
locking, DB-level invariants, and tests that exercise both.

## 2. Tech stack

- **Ruby on Rails, API mode** (`rails new --api`) — no views/asset
  pipeline needed, keeps the app focused on the domain logic and JSON
  endpoints.
- **PostgreSQL** — deliberately not SQLite. The whole point of this demo
  is row-level locking and a real `CHECK` constraint under concurrent
  access; SQLite's locking model wouldn't exercise that honestly.
- **RSpec + FactoryBot + Faker** for tests, **SimpleCov** for coverage.
- **Rubocop** (`rubocop-rails`, `rubocop-rspec` plugins) for style/lint.
- **GitHub Actions** for CI (RSpec + Rubocop on every push/PR to `main`).

## 3. Architecture

### Repo structure

```
license-manager/
│
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb
│   │   ├── license_checkouts_controller.rb      # POST /licenses/:license_id/checkouts
│   │   └── license_checkins_controller.rb       # POST /licenses/:license_id/checkins
│   │
│   ├── services/
│   │   └── licenses/
│   │       ├── checkout_service.rb               # business logic: allocate a seat (with_lock)
│   │       └── checkin_service.rb                # business logic: release a seat (with_lock)
│   │
│   ├── models/
│   │   ├── application_record.rb
│   │   ├── company.rb                            # has_many :licenses
│   │   ├── license.rb                            # belongs_to :company, has_many :license_checkouts
│   │   └── license_checkout.rb                   # belongs_to :license, enum status: active/returned
│   │
│   ├── jobs/application_job.rb                   # unused Rails scaffold (no real jobs defined)
│   └── mailers/application_mailer.rb             # unused Rails scaffold (no real mailers defined)
│
├── config/
│   ├── routes.rb                                 # nests checkouts/checkins under :licenses
│   ├── database.yml                              # Postgres; dev/test peer-auth + DB_* env overrides
│   └── ...                                       # application.rb, environments/, initializers/
│
├── db/
│   ├── migrate/
│   │   ├── ..._create_companies.rb
│   │   ├── ..._create_licenses.rb                # + CHECK constraint (0 <= active_seats_count <= max_seats)
│   │   └── ..._create_license_checkouts.rb       # + unique partial index (one active checkout/user/license)
│   ├── schema.rb
│   └── seeds.rb                                  # interview demo data (ARMADA company, 2 licenses)
│
├── spec/
│   ├── models/                                   # validations + DB constraint specs
│   │   ├── company_spec.rb
│   │   ├── license_spec.rb
│   │   └── license_checkout_spec.rb
│   ├── services/licenses/                        # the core business-logic specs
│   │   ├── checkout_service_spec.rb              # TDD'd happy/sad paths
│   │   ├── checkin_service_spec.rb               # TDD'd happy/sad paths
│   │   ├── seat_invariant_spec.rb                # randomized invariant + edge cases
│   │   └── checkout_service_concurrency_spec.rb  # 20-thread race-condition test
│   ├── requests/                                 # HTTP-level specs (status codes)
│   │   ├── license_checkouts_spec.rb
│   │   └── license_checkins_spec.rb
│   ├── factories/                                # FactoryBot definitions
│   └── rails_helper.rb / spec_helper.rb
│
├── .github/workflows/ci.yml                      # RSpec + Rubocop against real Postgres on every push/PR
├── .env.example                                  # DB_USERNAME/PASSWORD/HOST/PORT (+ _PRODUCTION variants)
├── .rubocop.yml
├── Gemfile / Gemfile.lock
├── README.md                                     # architecture, trade-offs, API examples
│
└── (bin/, config.ru, Rakefile, public/, log/, tmp/, storage/, vendor/ — standard Rails boilerplate)
```

### Request flow

```
HTTP request
     │
     ▼
LicenseCheckoutsController / LicenseCheckinsController   (thin: params → service → JSON+status)
     │
     ▼
Licenses::CheckoutService / Licenses::CheckinService      (business rules, License#with_lock)
     │
     ▼
License ──belongs_to── Company
   │
   └─has_many── LicenseCheckout (enum status: active/returned)
     │
     ▼
PostgreSQL  (CHECK constraint on active_seats_count, unique partial index on active checkouts)
```

- `LicenseCheckoutsController#create` / `LicenseCheckinsController#create`
  do nothing but pull params, call a service, and translate the service's
  `Result` into an HTTP status + JSON body.
- `Licenses::CheckoutService` / `Licenses::CheckinService` hold all the
  business rules: "is there a seat available", "does this user already
  have one", "lock the row before touching the counter".
- Models stay thin: validations and associations only, no business logic.

**Why a service object instead of putting this in the model or
controller?** The checkout/checkin operation touches two records
(`License` and `LicenseCheckout`) inside one locked transaction and
returns a result with a message — that doesn't map cleanly onto a single
ActiveRecord callback or a single model method. Pulling it into a
`Licenses::CheckoutService` keeps `License` a plain AR model (easy to
reason about, easy to test in isolation) and keeps the controller a thin
adapter between HTTP and the domain. It's also the unit the brief asked
to be tested directly, independent of routing.

## 4. Design decisions & trade-offs

### Pessimistic locking (`with_lock`), not optimistic or distributed

`License#with_lock` issues `SELECT ... FOR UPDATE` and wraps the block in
a transaction. Every concurrent checkout/checkin for the *same* license
serializes on that row, so the "check seat count, then increment" logic
can never race with itself.

- **Why not optimistic locking** (`lock_version` + retry)? It would work,
  but under contention (many users hitting the same popular license) it
  means a lot of wasted work and retries right when the system is busiest.
  Pessimistic locking just makes the second request wait briefly instead
  of failing and retrying.
- **Why not a distributed lock (Redis)?** It would add an external
  dependency and a whole new failure mode (lock not released, lock
  expiring mid-transaction) to solve a problem Postgres already solves
  natively with row locks. For a single-database app, that's solving the
  same problem twice.

### DB constraints as a second line of defense

The application logic is the *first* line of defense — `with_lock` plus
explicit checks before allocating a seat. But two more invariants are
enforced at the database level, independent of whether the Rails code is
correct:

- `CHECK (active_seats_count >= 0 AND active_seats_count <= max_seats)`
  on `licenses` — even a bug or a stray `UPDATE` run by hand can't push
  the counter out of bounds.
- A unique partial index on `license_checkouts (license_id, user_id)
  WHERE status = 'active'` — even if the service's `exists?` check were
  ever bypassed, the database itself refuses to create a second
  simultaneous active checkout for the same user/license pair.

This is "trust, but verify": application code expresses intent, the
database enforces the invariant no matter what called it.

### No automatic expiry/TTL on checkouts

Checkouts only end when a `checkin` call happens — there's no background
job that auto-expires a stale checkout after N hours. This is a
deliberate scope cut for the demo: building a correct expiry job (and
deciding what "stale" means, and reconciling it with `active_seats_count`)
is a real feature with its own edge cases, not something to bolt on
casually. See [§9](#9-what-id-improve-with-more-time).

### Why `POST .../checkins` instead of `DELETE .../checkout`

Checkin isn't really "delete the checkout resource" — the `LicenseCheckout`
row isn't deleted, it's marked `returned` and kept as a history record.
Modeling it as `POST .../checkins` (creating a "checkin event") matches
that semantics better than `DELETE`, which implies the record disappears.

## 5. Setup instructions

Requirements: Ruby (see `.ruby-version`), Rails, PostgreSQL running
locally.

```bash
bundle install
rails db:create
rails db:migrate
```

No `.env` file is required for local development — `config/database.yml`
relies on Postgres peer/local trust auth via the OS user, same as a
default `rails new --database=postgresql` setup. If your local Postgres
instead needs a username/password (common with Docker, Homebrew, or the
Windows installer), copy `.env.example` to `.env` and fill in
`DB_USERNAME`/`DB_PASSWORD` (and `DB_HOST`/`DB_PORT` if not on the
defaults) — `dotenv-rails` loads `.env` automatically in dev/test.

## 6. Running tests

```bash
bundle exec rspec
```

32 examples across three layers:

- **`spec/models`** (14) — validations, associations, and direct proof
  that the DB `CHECK` constraint and unique partial index reject bad
  data even when application-level validations are bypassed
  (`update_column`, raw inserts).
- **`spec/services/licenses`** (11) — `Licenses::CheckoutService` and
  `Licenses::CheckinService` were written test-first: each spec was
  confirmed *failing* (`NameError: uninitialized constant`) before the
  implementation existed. Includes a randomized invariant test (repeated
  checkout/checkin sequences never desync `active_seats_count` from the
  real row count) and a 20-thread concurrency test proving the row lock
  holds under real contention, not just in theory.
- **`spec/requests`** (7) — HTTP-level specs asserting status codes
  (201/200/409/404) end to end through the controllers.

A coverage report is generated by SimpleCov on every run, under
`coverage/index.html`. `app/models`, `app/services`, and
`app/controllers` are all at 100% line coverage.

Lint:

```bash
bundle exec rubocop
```

## 7. API usage examples

### Checkout — success (seat available)

```bash
curl -i -X POST http://localhost:3000/licenses/1/checkouts \
  -d "user_id=42"
```

```
HTTP/1.1 201 Created

{"message":"License allocated successfully","checkout":{"id":7,"license_id":1,"user_id":42,"status":"active","checked_out_at":"2026-06-21T18:00:00.000Z"}}
```

### Checkout — no seats left

```bash
curl -i -X POST http://localhost:3000/licenses/1/checkouts -d "user_id=43"
```

```
HTTP/1.1 409 Conflict

{"message":"No available license seats left"}
```

### Checkout — user already has an active session

```
HTTP/1.1 409 Conflict

{"message":"User already has an active session"}
```

### Checkout — license not found

```bash
curl -i -X POST http://localhost:3000/licenses/999/checkouts -d "user_id=42"
```

```
HTTP/1.1 404 Not Found

{"message":"License not found"}
```

### Checkin — success

```bash
curl -i -X POST http://localhost:3000/licenses/1/checkins -d "user_id=42"
```

```
HTTP/1.1 200 OK

{"message":"License returned successfully"}
```

### Checkin — no active checkout for this user

```
HTTP/1.1 409 Conflict

{"message":"No active checkout for this user"}
```

### List checkouts for a license (paginated, optionally filtered by status)

```bash
curl -i "http://localhost:3000/licenses/1/checkouts?status=active&page=1&per_page=20"
```

```
HTTP/1.1 200 OK

{"checkouts":[{"id":7,"license_id":1,"user_id":42,"status":"active","checked_out_at":"2026-06-21T18:00:00.000Z","checked_in_at":null}],"page":1,"per_page":20,"total_count":1}
```

`status` is optional (omit it to see the full history, active and
returned); an unrecognized value returns `422`. `per_page` is clamped to
1–100 (default 20).

## 8. CI

GitHub Actions (`.github/workflows/ci.yml`) runs on every push and pull
request to `main`:

1. Boots a real `postgres:16` service container — not SQLite, for the
   same reason as the tech-stack choice in §2: the suite exercises real
   row-level locking and a real `CHECK` constraint, so CI needs a real
   Postgres for a green run to actually mean something.
2. `bundle exec rails db:schema:load` to set up the test database.
3. `bundle exec rspec` — all 32 examples.
4. `bundle exec rubocop` — zero offenses.

See the badge at the top of this file for current status. `main` has a
branch protection rule requiring the `test` job to pass (and the branch
to be up to date) before a pull request can be merged.

## 9. What I'd improve with more time

- **Auto-expiry / TTL**: a background job (Active Job + a scheduler) that
  force-checkins sessions inactive for longer than some configurable
  window, so an employee who forgets to check in doesn't permanently
  hold a seat.
- **Authentication & multi-tenant isolation**: right now any caller can
  act as any `user_id` for any company's licenses. A real version would
  scope licenses to an authenticated company/user and reject cross-tenant
  access.
- **Audit log**: a separate append-only table recording every
  checkout/checkin attempt (including rejected ones), useful for support
  and abuse investigation.
- **Rate limiting**: protect the checkout endpoint from being hammered by
  a misbehaving client.
