# Testing guide

This document is the source of truth for the ArchiDep application's testing
conventions — _how we write tests_. It complements the **Test Support** section
of [`app/CONTRIBUTING.md`][contributing], which is the inventory of _what test
infrastructure exists_ (case templates, support helper modules, mocks, coverage
tooling). When in doubt: prescriptive rules live here, the catalogue of
available tooling lives in `CONTRIBUTING.md`.

The guiding principle across every layer: **a test should pin down the entire
observable behaviour of the code under test — every return value and every side
effect — with exact assertions, so that any unintended change makes a test
fail.** A test that only checks the parts we happened to think about is a test
that silently rots.

> **Status.** We are documenting our practices layer by layer as we write the
> tests. The [business layer](#business-layer) section is complete and
> authoritative. The remaining sections are placeholders to be filled in as we
> reach those layers.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [General conventions](#general-conventions)
- [Business layer](#business-layer)
  - [What a business-layer test must assert](#what-a-business-layer-test-must-assert)
  - [Test setup and structure](#test-setup-and-structure)
  - [Exact assertions on return values](#exact-assertions-on-return-values)
  - [Exact assertions on stored events](#exact-assertions-on-stored-events)
  - [Exact assertions on database side effects](#exact-assertions-on-database-side-effects)
  - [Deterministic time via an injectable clock](#deterministic-time-via-an-injectable-clock)
  - [Generated identifiers](#generated-identifiers)
  - [Asserting PubSub broadcasts](#asserting-pubsub-broadcasts)
  - [Asserting telemetry events](#asserting-telemetry-events)
  - [Asserting the absence of out-of-band effects](#asserting-the-absence-of-out-of-band-effects)
  - [Authorization and policy](#authorization-and-policy)
  - [Changeset and validation errors](#changeset-and-validation-errors)
  - [Covering every branch](#covering-every-branch)
  - [Testing create use cases](#testing-create-use-cases)
  - [Testing update use cases](#testing-update-use-cases)
  - [Testing read use cases](#testing-read-use-cases)
  - [Factories](#factories)
  - [Contract-checking the real implementation](#contract-checking-the-real-implementation)
- [Web layer (LiveViews & controllers)](#web-layer-liveviews--controllers)
- [Channels](#channels)
- [Plumbing (router, plugs, auth)](#plumbing-router-plugs-auth)
- [Helpers & components](#helpers--components)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

---

## General conventions

These apply to every layer; the per-layer sections build on them.

- **Framework.** Tests use [ExUnit][ex-unit]. All new code ships with relevant
  tests under `test/`.
- **TDD by default.** Prefer writing tests before or alongside the code, and
  cover edge cases and error handling, not just the happy path.
- **Doctests for simple pure functions.** Prefer [doctests][ex-unit-doctests]
  for helper modules whose functions are simple and have illustrative
  input/output.
- **Split GenServer API from implementation.** For [GenServer][gen-server]
  modules, write separate tests for the public API and the implementation so the
  logic can be unit-tested without the process machinery (see the
  `GenServerProxy`/`NoOpGenServer` utilities listed in `CONTRIBUTING.md`).
- **Real code vs. mocks.** Test a context's _own_ logic against the real
  implementation under `DataCase`; mock a context's behaviour only when testing
  a _different_ layer (the web layer) or a complex internal dependency in
  isolation. Always back critical paths with at least one mock-free integration
  test. See [Contract-checking the real
  implementation](#contract-checking-the-real-implementation).
- **Run the tests you changed.** Prefer running specific files or directories
  while iterating; see the testing commands in `CONTRIBUTING.md`.

## Business layer

The business layer is the bounded contexts: their facades, use cases, and
schemas (`lib/archidep/<context>/…`). This is where the densest logic lives —
orchestration inside `Ecto.Multi` transactions, authorization, auditing, and the
state that the rest of the system depends on. It is also where exactness matters
most, because a use case's behaviour _is_ its contract.

Business-layer tests run under [`ArchiDep.Support.DataCase`][data-case] with the
SQL sandbox, so they exercise real database writes against a transaction that is
rolled back after each test. They should be `async: true` whenever possible.

The canonical worked example is
[`log_in_or_register_with_switch_edu_id_test.exs`][exemplar]. New business-layer
tests should pattern-match on it.

### What a business-layer test must assert

Before considering a use-case test complete, every item on this checklist must
be addressed — either with an exact assertion, or with a deliberate negative
assertion that the effect did _not_ occur:

1. **The return value**, by exact equality.
2. **Every stored event**, by exact equality, including the full event payload,
   stream, version, and metadata — and that _no other_ events were stored.
3. **Every database side effect**: rows created, updated, deleted — asserted by
   exact equality on the full schema struct, including version bumps and
   timestamps.
4. **Pinned row counts**: that exactly the expected number of rows exist in
   every affected table — no stray inserts.
5. **Every PubSub broadcast** the use case is expected to emit (and none that it
   should not).
6. **Every telemetry event** the use case is expected to emit.
7. **The absence of out-of-band effects** on failure paths: when a use case
   returns an error, assert that nothing was written, broadcast, or emitted.

A test that leaves any of these unaddressed is incomplete, even if it passes.

### Test setup and structure

- **One use case per test file by default.** Name the file after the use case
  (`<use_case>_test.exs`) and the module after it. If it grows unwieldy, split
  it into multiple files by branch, but avoid grouping multiple use cases in one
  file unless their tests are trivially short.
- **Group assertions into composable private helpers, chained with `|>`.** Each
  helper makes the exact assertions for one concern (the auth result, the stored
  event, the resulting session, …) and returns the value the next helper
  consumes, so the main assertions form a single `|>` pipeline rather than a
  sequence of separate statements. See `assert_auth/3`,
  `assert_registered_event/5`, and `assert_user_session_for_new_user/5` in the
  [exemplar][exemplar], and `assert_updated_class/3` →
  `assert_class_updated_event/3` → `assert_persisted_class/2` in
  [`update_class_test.exs`][update-class-test]. When a later step also needs a
  value produced earlier in the chain, keep that value bound in the test (e.g.
  the struct pattern-matched from the use-case call) or have a helper thread it
  through its return value — do not abandon the pipeline for separate
  statements.
- **Build vs. insert.** Use factory `build` for the input data you pass into the
  use case and factory `insert` for the pre-existing state the use case reads.
- **Keep factory calls visible; don't wrap them in helpers.** Call
  `Factory.insert(:thing, %{…})` directly at each call site rather than hiding
  it behind a custom `insert_thing/1` helper — the wrapper obscures standard
  ExMachina use and what the fixture actually is, for little gain. If a
  non-trivial set of options genuinely repeats across call sites, hoist a plain
  map of defaults in the test and merge per-call (`Map.merge(defaults, %{…})`)
  rather than a helper function — but for a single flag, just inline it
  (`Map.merge` is longer than repeating `active: true`).
- **Verify mocks.** Use `setup :verify_on_exit!` so any contract-checked mock
  expectations are verified at the end of the test.

### Exact assertions on return values

Assert the whole returned struct by equality, not a partial pattern match.
Pattern-match first to bind the values you cannot predict (generated IDs,
tokens), then assert full equality so that every _other_ field is pinned —
including the ones that should be `nil`:

```elixir
assert %Authentication{principal_id: id, session_id: session_id, session_token: token} = auth

assert auth == %Authentication{
         principal_id: id,
         username: "root@archidep.ch",
         root: true,
         session_id: session_id,
         session_token: token,
         session_expires_at: session_expires_at,
         impersonated_id: nil
       }
```

The difference matters: `assert %Authentication{root: true} = auth` passes even
if an unexpected `impersonated_id` leaks in; the equality form does not.

### Exact assertions on stored events

Events are the audit log and the integration contract between contexts, so they
are asserted exhaustively. Read the events back from the store and assert the
full `%StoredEvent{}` by equality — payload `data` map (every key), `stream`,
`version`, `type`, `initiator`, `causation_id`, `correlation_id`, `meta`, and
`occurred_at`.

Bind the list match so the assertion _also_ pins the count:

```elixir
assert [%StoredEvent{id: event_id, occurred_at: occurred_at} = event] =
         fetch_new_stored_events()

assert event == %StoredEvent{__meta__: loaded(StoredEvent, "events"), id: event_id, …}
```

Use the [`DataCase`][data-case] helpers:

- `fetch_new_stored_events/0` (and `/1` to exclude events that pre-existed the
  action) returns events ordered by occurrence.
- `assert_no_stored_events!/0` (and `/1`) asserts that no events — or no events
  other than the given ones — were stored.

Use `loaded/2` and `not_loaded/2` (also from `DataCase`) to express the expected
`__meta__` and unloaded-association states precisely.

### Exact assertions on database side effects

Read the affected rows back through `Repo` and assert the full schema struct by
equality. Prefer a single query that preloads the associations touched by the
use case, so one equality assertion pins the state of several tables at once
(account, identity, linked records). Assert:

- every persisted field, including `active` flags and foreign-key columns;
- **version columns**, asserting the exact post-action value (e.g. `version + 1`
  where an optimistic-lock update occurred, and the _unchanged_ value where it
  did not);
- the `__meta__` loaded state and `not_loaded/2` for associations that should
  remain unloaded.

**Negative assertions are mandatory, not optional.** On a path where a row must
_not_ change, assert it is byte-for-byte the record you inserted
(`assert [^existing] = Repo.all(Schema)`). On a path where a table must remain
empty, assert `Repo.all(Schema) == []`. These negative assertions are currently
missing from some tests and must be added.

**Pin row counts.** Binding `[only_one] = Repo.all(…)` asserts both the contents
_and_ that exactly one row exists. Do this for every table the use case could
plausibly write to, including tables it is _not_ supposed to touch, so a stray
insert is caught.

**Reconstruct the expected row from the audit event, not from the return
value.** Assert the stored event _first_, then build each expected database row
from the values that event carries — ids, foreign keys, `occurred_at` —
supplying by hand only what the event deliberately omits, such as a redacted
secret. This is the ordering the [exemplar][exemplar] uses: the event helper
runs before the row/session helper, which receives the event and pulls fields
out of it. It buys two things:

- It proves the **event is a complete audit log.** If a column cannot be rebuilt
  from the event payload — or implied by the event's _type_, e.g. a "link
  created" event meaning `active: true` and `used_at: nil` — that is a gap in
  the audit trail, surfaced here as a failing assertion rather than discovered
  later. Genuinely sensitive values (tokens, password hashes) are the deliberate
  exception: they are kept out of the event and passed into the row helper
  separately.
- It stops a row-assertion helper from being handed the use case's **own output
  and silently checking it against itself.** Pass these helpers the event plus
  the minimal extra inputs — never the returned struct. A helper that takes the
  whole returned entity invites `assert Repo.get!(…) == returned`, which holds
  by construction and proves nothing about what was actually persisted.

### Deterministic time via an injectable clock

Timestamps are side effects and must be asserted exactly, not approximately. A
test that reads `created_at` back out of the row and asserts the row equals
itself proves nothing about the value; a test that asserts `expires_at` is
"roughly 30 days out" cannot catch an off-by-one in the validity window.

The practice: **inject the current time** rather than calling
`DateTime.utc_now/0` deep inside a use case. The test fixes a known instant and
asserts that every persisted and emitted timestamp equals exactly that instant
(or a known offset from it — e.g. `session_expires_at == DateTime.add(now, 30,
:day)`). This applies to **dates** too: a use case that filters or stamps by
"the current day" must derive it from the clock
(`DateTime.to_date(Clock.now())`), not `Date.utc_today/0`, so the test can pin
"today".

**Inject the clock the same way contexts are injected, not by threading `now`
through every function.** Adding a `now` argument to each public use case would
leak a test concern into the contract; instead we use the dependency-injection
pattern the web layer already uses for context mocks. The `ArchiDep.Clock`
facade (a `now/0` callback defined by `ArchiDep.Clock.Behaviour`) is resolved
through `Application.compile_env!/2`: it points at `ArchiDep.Clock.SystemClock`
in production and at the `Hammox.defmock`'d `ArchiDep.Clock.Mock` in the test
environment. Business logic calls `ArchiDep.Clock.now/0` instead of
`DateTime.utc_now/0`, and each test sets the instant it wants:

```elixir
stub(ArchiDep.Clock.Mock, :now, fn -> ~U[2025-01-01 12:00:00.000000Z] end)
```

The reason this works under `async: true` is the **same** reason the context
mocks do: Mox/Hammox dispatch to the _calling process's_ expectations, so each
async test sets its own clock without affecting concurrent tests. A global
`Application.put_env` of "the current time" would **not** be safe under async —
one test's clock would bleed into others. Use the mock, not a global value.

`DataCase` installs a **default stub** that returns the real system time, so
tests that don't care about time need no clock setup and behave as before. Only
tests that assert timestamps override it, pinning a fixed instant with their own
`stub`/`expect`.

One caveat, identical to the context mocks: the stub is only seen when the code
under test runs **in the test process**. The use cases documented here run their
transaction synchronously in the caller, so this holds. If a use case ever
delegates timestamping to a spawned `Task`/`GenServer`, that process needs a Mox
allowance.

Until a given use case has been converted to the injectable clock, a test may
temporarily fall back to cross-checking that related timestamps are mutually
consistent (e.g. that the session's `created_at` equals the event's
`occurred_at`), but the end state is an exact assertion against the injected
instant, and new code should be written that way from the start.

### Generated identifiers

We deliberately do **not** inject UUID generation, even though it would let us
assert generated IDs by literal value. The distinction from time is the point:

- A **timestamp's value encodes behaviour** — the validity window, the
  touch-`updated_at`-only-when-changed rule, event ordering — so pinning it
  catches real bugs.
- A **UUID's value is arbitrary identity** that encodes nothing. The property
  worth testing is the _wiring_: that the same id flows from the inserted row
  into the event payload, the session, and the returned result. The
  bind-and-cross-reference pattern already proves this exactly — pattern-match
  to bind the generated id once, then reuse that binding throughout the equality
  assertions:

```elixir
assert %Authentication{principal_id: id, session_id: session_id} = auth
# reuse `id` / `session_id` in the expected StoredEvent and UserSession structs
```

Injecting UUIDs would add ceremony for no behavioural coverage and would be _more_
fragile than a clock: a fixed generator must yield distinct values per call, so
the test would become coupled to call order and count. Bind and cross-reference
instead.

**Randomly generated secrets** — login-link tokens, session tokens — are bound
and cross-referenced the same way, because their exact value is just as
unpredictable. But unlike a UUID, a secret's _quality_ encodes behaviour: its
length and its randomness are the entropy that makes it unguessable. So assert
those properties in addition to binding the value, using the
`assert_secure_random_token/1` helper (from
`ArchiDep.Support.TokenTestHelpers`), so that shortening, emptying, or
substituting a low-entropy placeholder (`"seeeeeecret"`) for the secret fails a
test:

```elixir
assert %LoginLink{token: token} = login_link
assert_secure_random_token(token)
```

The helper asserts a minimum byte length _and_ a minimum number of distinct byte
values — a cheap entropy floor that random `:crypto.strong_rand_bytes/1` output
clears comfortably while a hand-written constant does not.

### Asserting PubSub broadcasts

PubSub broadcasts are part of the **public API** of each context — other parts
of the system subscribe to them — so they are asserted like any other output.
Subscribe to the relevant topic(s) before invoking the use case, then
`assert_receive` the expected message after:

```elixir
Phoenix.PubSub.subscribe(ArchiDep.PubSub, "accounts:preregistered-users:#{student.id}")
# … invoke the use case …
assert_receive {:preregistered_user_updated, broadcast}
```

`assert_receive` is the right tool for the positive case: it returns the instant
the message arrives and only blocks up to its timeout when the message is
_absent_, so it costs nothing on the happy path. Assert on _every_ topic the use
case is expected to publish to, and assert the **absence** of a broadcast on
paths where none should occur (see
[below](#asserting-the-absence-of-out-of-band-effects)).

> **Interim note (DDD refactoring).** Until the DDD refactoring lands, broadcast
> payloads are still being reshaped, so for now PubSub assertions may stay
> _partially black box_: assert that the expected message tag is received on the
> expected topic, without pinning the full payload struct. Leave a "TODO DDD"
> comment indicating that assertions must be completed. Once the DDD work
> stabilizes the broadcast shapes, these become exact equality assertions on the
> payload like everything else.

### Asserting telemetry events

Use cases emit telemetry (e.g. `[:archidep, :accounts, :auth, :login]`). Assert
every expected event using [`ArchiDep.Support.TelemetryTestHelpers`][telemetry]:

```elixir
attach_telemetry_handler!(context, [:archidep, :accounts, :auth, :login])
# … invoke the use case …
assert %{metadata: %{method: :switch_edu_id, principal_id: ^principal_id}} =
         assert_telemetry_event!([:archidep, :accounts, :auth, :login])
```

`attach_telemetry_handler!/2` attaches a handler that forwards events to the
test process and detaches on exit; `assert_telemetry_event!/1` asserts one was
received and returns its measurements/metadata for further assertions.

### Asserting the absence of out-of-band effects

Failure and no-op paths need the mirror image of the success assertions. When a
use case returns an error (or deliberately does nothing), assert that it had
**no** side effects:

- no rows created/changed (`Repo.all(Schema) == []` or `[^unchanged] = …`);
- no events stored (`assert_no_stored_events!/0,1`);
- no PubSub broadcast (subscribe beforehand, then refute — see below);
- no telemetry event emitted (attach a handler beforehand, then refute).

**Prefer `refute_received` over `refute_receive` for these checks.**
`refute_receive` blocks for its full timeout (100 ms by default) on _every_
call, which taxes a large async suite; `refute_received` checks the mailbox
instantly. Instant checking is not merely faster here, it is **correct**,
because both effects are delivered _synchronously, before the use case returns_:

- the default `Phoenix.PubSub` (PG) adapter `send`s to local subscribers inside
  `broadcast/3`;
- `:telemetry.execute/3` runs handlers synchronously in the calling process, and
  our handler `send`s to the test process before returning.

So once the (synchronous, in-process) use case has returned, the mailbox is
settled — a message cannot arrive later — and `refute_received` cannot race.

Reserve `refute_receive` (with an explicit short timeout) for the genuinely
**asynchronous** case, where delivery could happen _after_ the code under test
returns — a spawned task, a `GenServer` cast, or cross-node PubSub. In all
cases, subscribe/attach _before_ invoking and refute _after_ the call returns;
that ordering is what makes the instant check sound.

This is what proves a transaction actually rolled back and that an error path is
truly inert.

### Authorization and policy

Where a use case enforces authorization, test it from both sides: that an
authorized principal succeeds, and that each unauthorized principal is rejected
with the exact expected error — **and** that the rejection produced none of the
side effects above. Impersonation and root-only operations have their own rules;
assert them explicitly rather than relying on a single happy-path principal.

### Changeset and validation errors

Validations live in the **schema changesets**, so that is where they are tested
**exhaustively** — one case per rule, with the exact messages, in the schema's
own unit test (see [`class_test.exs`][class-test], which covers every
`teacher_ssh_public_keys` rule). Pure changeset validations need no database, so
those tests build the changeset and call `errors_on/1` directly; a DB-backed
validation (uniqueness) runs under `DataCase`.

A **use case's** test does _not_ re-test every rule — that would duplicate the
schema suite and let it rot in two places. It includes a **minimal smoke test**
instead: drive the `{:error, changeset}` path with one representative invalid
input (usually a missing required field) and assert the exact errors map _and_
that the call left no side effects. That smoke test is not redundant — it pins
what the schema test cannot: that the use case surfaces the invalid changeset as
an error, rolls back, and writes/broadcasts/emits nothing.

Repeat a _specific_ validation in the use case only when it is of particular
interest at that boundary:

- **DB-backed / uniqueness checks** (`unsafe_validate_unique` +
  `unique_constraint`): they depend on pre-existing database state and on the
  use case's transaction, so the use-case test verifies the conflict end to end —
  it is rejected _and_ the transaction rolled everything back — which the schema
  test does not. (The class name-uniqueness test is an example.)
- **Business invariants and security-relevant rules** important enough to assert
  at the boundary that enforces them (e.g. the login-link root invariant).

This division applies to **schema** validations. Guards that live in the use
case itself — authorization, input-format checks (`validate_uuid`),
cross-context preconditions — have no schema test to defer to, so they are
always covered in the use case's own test.

**Choosing the right changeset is a use-case concern.** Schemas usually expose
more than one changeset — commonly a create and an update one, with different
cast lists, defaults, or locking. The schema test covers what each changeset
does; proving the use case calls the _right_ one is the use-case test's job, and
it is asserted through the observable result, not by spying on the call. When
the distinction matters — a field settable on update but not on creation (or
vice versa), a default applied only on create, a version bumped only on update —
assert it: that the field is applied when it should be and ignored when it
should not, in the persisted row and the emitted event.

### Covering every branch

Each distinct path through a use case is its own test: new vs. existing record,
active vs. inactive, root vs. student, first login vs. re-login, the
single-match vs. zero-or-many cases, optimistic-lock conflicts, and so on. The
[exemplar][exemplar] enumerates the register/login/unauthorized branches this
way. Aim for one test per observable behaviour, each making the full set of
assertions from the [checklist](#what-a-business-layer-test-must-assert).

### Testing create use cases

Our factories generate random-but-valid data, which keeps tests honest — but a
single run rarely lands on the interesting combinations (every optional set, or
none). So a "create" use case gets **three** happy-path tests, each pinning the
full output exactly (the random one included — you pass the factory's output in,
so you hold every value and assert against it):

1. **Random** — let the factory fill as much as possible; pin only what the test
   genuinely cannot run without (often nothing). Over many CI runs this
   exercises field combinations no single pinned test would. For this to be
   meaningful the factory must generate _every_ optional field (including ones
   that are off-by-default), so extend the `*_data` factory if it doesn't.
2. **Minimal** — only the required fields, every optional left out, pinning the
   defaults the use case applies (empty lists, `nil`s). **Build this input by
   hand** rather than via the factory, so the minimal valid set is explicit and
   does not silently drift when the factory changes.
3. **Full** — every optional set to a non-default value, so the test pins that
   each one is persisted and audited. **Build this input by hand** too:
   ExMachina has no trait system, so `build(:thing_data, :full)` does not work —
   pass an explicit map (drawing valid values from sub-factories where useful,
   e.g. SSH fingerprints).

These complement, not replace, the error/branch tests (authorization failure,
each validation failure, conflicts). The matching strategy for **update** use
cases is in [Testing update use cases](#testing-update-use-cases).

A worked example is [`create_class_test.exs`][create-class-test]. Writing the
full test there surfaced two bugs where a field had been added to the schema but
not propagated: the `ClassCreated` event and the `class_data` type both omitted
the SSH host-key fingerprints — exactly the kind of gap the
reconstruct-the-row-from-the-event rule and a full-set test are meant to catch.

### Testing update use cases

An update use case starts from an existing persisted record, so its tests must
prove two things a create test cannot: that the supplied fields _overwrite_ the
prior values, and that the record's `version` and `updated_at` advance while its
identity and `created_at` stay fixed. Insert the starting record with a factory,
then read it back from the database as the baseline to assert against (the
factory randomises `version`/`created_at`, so derive every expected value from
that persisted baseline rather than pinning it). Reconstruct the expected row
from the **audit event** for every field the event carries, and take only what
the update genuinely leaves untouched (`created_at`, unrelated associations)
from the baseline.

Like a create, an update gets **three** happy-path tests, each pinning the full
output exactly. The first two are mirror images that together exercise every
optional in both transition directions:

1. **Update everything** — start from a **minimal** record (every optional at
   its default) and update every field to a non-default value. This drives the
   empty → set direction for each optional, and because every field differs
   before/after, a field missing from the update changeset's cast list fails to
   change and is caught. Build both the minimal starting record and the full
   update map by hand (drawing valid values from sub-factories where useful).
2. **Clear every optional** — start from a **fully-populated** record and reset
   every optional to its default. This drives the set → empty direction and pins
   that the update overwrites previously-set values rather than retaining them —
   a failure mode unique to update. Build the input by hand.
3. **Random** — start from a random record and update with the factory's
   `*_data` output, exercising field combinations across CI runs.

These complement the error/branch tests, which for an update add paths a create
has no equivalent of:

- **Not found** — a well-formed but unknown id returns the not-found error with
  no side effects. If the use case reports not-found _before_ its authorization
  check, assert that an unauthorized caller still gets not-found (not an
  authorization error) for an unknown id. A malformed (non-UUID) id cannot be
  exercised through a `Hammox.protect`ed use case whose contract types the id as
  `Ecto.UUID.t()` — the guard against it belongs to the schema/web layer.
- **Same-value uniqueness** — a uniqueness check that excludes the record being
  updated must let it keep its own value; assert that re-saving the record with
  its current name succeeds, alongside the usual "rename to another record's
  name is rejected" test.
- **Optimistic-lock conflict** — when the use case re-fetches the record and
  accepts no caller-supplied version, a stale-version conflict cannot be
  triggered deterministically from a single process, so it is not unit-tested;
  the version _bump_ is still asserted in every happy-path test. Use cases that
  _do_ take a caller-supplied version should test the conflict.

A worked example is [`update_class_test.exs`][update-class-test]. As with the
create spike, writing it surfaced the same two propagation gaps on the update
path — `Class.update` was not clock-injected, and the `ClassUpdated` event
omitted the SSH host-key fingerprints — both fixed so timestamps are assertable
and the row is fully reconstructable from the event.

### Testing read use cases

A read (query) use case writes nothing — no rows, events, broadcasts, or
telemetry — so the [checklist](#what-a-business-layer-test-must-assert)
collapses to two things: the **exact returned value** and the **absence of side
effects** (`assert_no_stored_events!()`; reads publish nothing, so there is no
broadcast to await). Insert the pre-existing state with factory `insert` and
assert the return against those fixtures by full equality (the insert-returned
struct equals the re-read row).

- **Assert lists by full-list equality, in order.** Pin _every_ `ORDER BY` key
  in the fixtures so the expected order is unambiguous, and insert them out of
  order so the test proves the query sorts rather than returning insertion
  order. Include a fixture that forces each tie-break (two rows equal on all
  earlier keys, differing only on the next), and one that exercises `NULL`
  ordering (PostgreSQL sorts `NULL`s first under `desc`) — a reviewer who
  changes the clause should break the test. Where a sort key is irrelevant to a
  given fixture's position, let the factory auto-generate it (e.g. unique names)
  rather than inventing values.
- **Test the empty case.** With no matching rows the use case returns `[]` (or
  its documented empty value), still with no side effects — a distinct branch
  from the populated list, and a cheap guard against a query that, say, only
  works once a row exists.
- **Cover each filter branch and boundary with one fixture.** For a windowed
  query, insert one row per reason to include (inside the window, open-ended
  bounds) and one per reason to exclude (each predicate that fails), plus rows
  exactly on each inclusive boundary. Assert the result contains exactly the
  included rows. Any "now"/"today" the filter depends on must come from the
  injected clock (see [Deterministic
  time](#deterministic-time-via-an-injectable-clock)) so the window is
  deterministic.
- **Existence-masking on single-resource reads.** When a `fetch`/`get` use case
  hides authorization failures as "not found" (so it cannot leak the existence
  of a resource the caller may not see), assert that an unauthorized caller gets
  the exact same not-found result as for an unknown id — not an authorization
  error and not a raise.

A worked example is [`read_classes_test.exs`][read-classes-test]. Writing it
surfaced the same class of gap as the create/update spikes:
`list_active_classes` derived "today" from `Date.utc_today()` instead of the
injected clock, so it could not be tested deterministically; it now uses
`DateTime.to_date(Clock.now())`.

### Factories

We use [ExMachina][ex-machina] factories scoped per context.

- **Where they live.** Factory modules are namespaced under `ArchiDep.Support`,
  suffixed `Factory`, one per context (`ArchiDep.Support.AccountsFactory` in
  `test/support/accounts_factory.ex`, and likewise `CourseFactory`,
  `EventsFactory`, `ServersFactory`, …). Shared building blocks live in
  `ArchiDep.Support.Factory` and `ArchiDep.Support.FactoryHelpers`.
- **`build` vs. `insert`.** Prefer `build` (no database) for the input data you
  pass into a use case; use `insert` for the pre-existing state the use case
  reads from the database.
- **Reuse before creating.** Prefer reusing existing factories; if they don't
  fit, extend them or add a factory in the appropriate context rather than
  hand-rolling data inline.
- **Random but valid.** Generate randomized-but-valid data with [Faker][faker]
  and ExMachina sequences (for unique fields like usernames/emails). Randomness
  keeps tests honest about what they actually depend on — if a test passes only
  for one specific value, pin that value explicitly in the factory call. Write
  hard-coded values when a particular edge case demands it.

### Contract-checking the real implementation

We use [Hammox][hammox] — which builds on [Mox][mox] and additionally verifies
at runtime that expectations conform to the mocked behaviour's typespecs. Every
context module has a behaviour, and mocks are defined with `Hammox.defmock` in
`test/support/mocks.ex` (the per-context `ContextMock`s plus
`ServerManagerMock`, `Ansible.Mock`, `Http.Mock`, and the `Clock.Mock` from [the
time section](#deterministic-time-via-an-injectable-clock)).

Business-layer tests call the **real** use-case implementation (under
`DataCase`), not a context mock — the context mocks exist so the web layer can
be tested in isolation. To additionally verify that the real implementation
honours its behaviour's typespec, wrap it with `Hammox.protect/2`:

```elixir
setup_all do
  %{
    log_in_or_register_with_switch_edu_id:
      protect({Context, :log_in_or_register_with_switch_edu_id, 2}, Behaviour)
  }
end
```

This returns a function that is contract-checked against the behaviour's
typespec on every call, so any drift between implementation and contract fails
the test.

---

## Web layer (LiveViews & controllers)

_To be documented when we write the web-layer tests. This layer uses
`ConnCase`/`LiveCase`, the shared auth setup fixtures, and Hammox mocks of the
context behaviours so LiveViews and controllers are tested in isolation from the
real business logic. Topics to cover: mounting with auth fixtures, mocking
context calls, asserting rendered HTML (Floki), form submission and validation,
flash/notification assertions, PubSub-driven updates, and anonymous-redirect
checks._

## Channels

_To be documented when we write the channel tests. This layer uses
`ChannelCase` (`Phoenix.ChannelTest`). Topics to cover: connect/auth, join, and
`handle_in`/`handle_info`._

## Plumbing (router, plugs, auth)

_To be documented when we write the plumbing tests. ConnCase request tests for
the auth controller, `live_auth`, and the router pipelines. Topics to cover:
redirect/halt/assign assertions and authenticated vs. anonymous pipelines._

## Helpers & components

_To be documented when we write the helper and component tests. Topics to cover:
unit-testing pure helper functions (and doctests), and rendering/asserting
function components with Floki._

[contributing]: ../CONTRIBUTING.md#testing
[data-case]: ../test/support/data_case.ex
[telemetry]: ../test/support/telemetry_test_helpers.ex
[exemplar]: ../test/archidep/accounts/log_in_or_register_with_switch_edu_id_test.exs
[create-class-test]: ../test/archidep/course/create_class_test.exs
[update-class-test]: ../test/archidep/course/update_class_test.exs
[read-classes-test]: ../test/archidep/course/read_classes_test.exs
[class-test]: ../test/archidep/course/schemas/class_test.exs
[ex-unit]: https://hexdocs.pm/ex_unit/ExUnit.html
[ex-unit-doctests]: https://hexdocs.pm/ex_unit/ExUnit.DocTest.html
[gen-server]: https://hexdocs.pm/elixir/GenServer.html
[ex-machina]: https://hexdocs.pm/ex_machina/readme.html
[faker]: https://hexdocs.pm/faker/readme.html
[hammox]: https://github.com/msz/hammox
[mox]: https://hexdocs.pm/mox/Mox.html
