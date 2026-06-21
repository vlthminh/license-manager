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

```
Controller  ->  Service Object  ->  ActiveRecord Model  ->  PostgreSQL
(thin)          (business logic)     (validations,           (CHECK constraint,
                                       associations)           unique index)
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
needs a password, set `DATABASE_URL` before running any `rails` command:

```bash
export DATABASE_URL=postgres://user:password@localhost:5432/license_manager_development
```

## 6. Running tests

```bash
bundle exec rspec
```

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

## 8. CI

GitHub Actions runs `bundle exec rspec` and `bundle exec rubocop` against
a real Postgres service container on every push/PR to `main`. See the
badge at the top of this file and `.github/workflows/ci.yml`.

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
- **Pagination/listing endpoints**: e.g. `GET /licenses/:id/checkouts` to
  see who currently holds a seat — useful for admins, not modeled here
  since it wasn't part of the core problem.
