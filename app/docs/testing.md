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
> authoritative. The [web layer](#web-layer-liveviews--controllers) section is
> the proposed canon — being settled and human-reviewed through the web-layer
> spike — so treat it as authoritative for new web tests but expect refinements.
> The remaining sections are placeholders to be filled in as we reach those
> layers.

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
  - [Testing pure predicate functions over a date window](#testing-pure-predicate-functions-over-a-date-window)
  - [Testing create-or-update (upsert) changesets](#testing-create-or-update-upsert-changesets)
  - [Covering every branch](#covering-every-branch)
  - [Testing create use cases](#testing-create-use-cases)
  - [Testing update use cases](#testing-update-use-cases)
  - [Testing read use cases](#testing-read-use-cases)
  - [Testing delete use cases](#testing-delete-use-cases)
  - [Testing sub-aspect (child-association) update use cases](#testing-sub-aspect-child-association-update-use-cases)
  - [Factories](#factories)
  - [Contract-checking the real implementation](#contract-checking-the-real-implementation)
- [Web layer (LiveViews & controllers)](#web-layer-liveviews--controllers)
  - [What a web-layer test asserts — two kinds of output](#what-a-web-layer-test-asserts--two-kinds-of-output)
  - [Asserting the DOM: a meaningful projection, not exact markup](#asserting-the-dom-a-meaningful-projection-not-exact-markup)
  - [Tools](#tools)
  - [Mounting, auth, and mocking contexts](#mounting-auth-and-mocking-contexts)
  - [Forms, validation, and interactions](#forms-validation-and-interactions)
  - [Flash, notifications, and PubSub-driven updates](#flash-notifications-and-pubsub-driven-updates)
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
  while iterating; see the testing commands in `CONTRIBUTING.md`. When touching
  `async: true` tests — especially ones asserting PubSub broadcasts or other
  process-global state the SQL sandbox does not isolate — check their stability
  with `mix test … --repeat-until-failure <n>`, which re-seeds each run and
  stops at the first failure; a single green run can hide an ordering-dependent
  race.

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
   timestamps. **Reconstruct the expected row from the stored event (asserted in
   step 2), never by comparing the re-read row to the use case's return value**
   — `assert Repo.get!(…) == returned` holds by construction and proves nothing
   (see [Exact assertions on database side
   effects](#exact-assertions-on-database-side-effects)).
4. **Pinned row counts**, asserted as a diff from before the call
   (`assert_row_count_diff/2` / `assert_no_row_count_diff/1`): every affected
   table changed by exactly the expected delta and no other watched table
   changed — no stray inserts or deletes.
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
- **Keep factory calls visible; never hide a single insert behind a helper.**
  This is a recurring review failure — read it before writing any fixture. The
  one hard rule: a **single** `Factory.insert`/`build` call must stay visible at
  the test call site. Do not wrap one insert in a helper to "DRY" it.

  | Form                                                                                                                        | Verdict    |
  | --------------------------------------------------------------------------------------------------------------------------- | ---------- |
  | `Factory.insert(:thing, …)` inline at the call site                                                                         | ✅ default |
  | a pure **attrs-builder** that returns options, insert still at the call site (`Factory.insert(:thing, thing_attrs(extra))`) | ✅         |
  | a named `setup` for setup that repeats verbatim across a file                                                               | ✅         |
  | `insert_thing(opts)` / `insert_account` / `insert_session` — a helper that **performs** one insert                          | ❌ never   |

  The test below has the failure mode: every `insert_account`/`insert_session`
  in a file is the ❌ form, even when each "only forwards a couple of options."
  Forwarding options is exactly what an attrs-builder returning **data** does
  without hiding the insert — reach for that, or just inline (for one or two
  options the inline call is shorter than the wrapper anyway).

  **The one exception — multi-entity orchestration in a shared helper module.**
  A fixture that is several **interdependent** inserts plus the linking between
  them (not one insert with options) — e.g. an active student account: an active
  class, an active student in it, and a user account linked to that student in
  both directions — may live as a named helper **in a shared `*TestHelpers`
  support module** that **returns the built fixtures**. See
  [`CourseTestHelpers.register_student`](../test/support/course_test_helpers.ex)
  and
  [`AccountsTestHelpers.register_active_student`](../test/support/accounts_test_helpers.ex).
  The line is about _shape_, not just location: orchestration of a whole
  multi-row graph → a returning helper is fine; a wrapper around a single
  `Factory.insert` → always inline it (or use an attrs-builder). When unsure,
  inline.

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

**Pin row counts as a diff, not as absolute state.** A use case's effect on row
counts is best stated as _what it changed_: snapshot the watched tables with
[`count_rows/1`][data-case] before the call, then assert the delta afterwards
with `assert_row_count_diff/2` (each listed table changed by exactly its delta;
every other watched table is unchanged) or `assert_no_row_count_diff/1` for a
path that must write nothing:

```elixir
# at the top of the test module:
@affected_tables [Class, ExpectedServerProperties, StoredEvent]

# in every test that calls the use case:
previous_counts = count_rows(@affected_tables)
assert {:ok, _class} = create_class.(auth, data)
assert_row_count_diff(previous_counts, %{Class => 1, ExpectedServerProperties => 1, StoredEvent => 1})
```

This reads as the behaviour ("one class and its properties row added, one event
stored, nothing else touched") and stays correct regardless of how many rows
pre-existed — unlike `[only_one] = Repo.all(…)`, which asserts an absolute
end-state ("exactly one row exists") that only makes sense on an empty table and
says nothing about _what the call did_.

**Declare the watch-set once with `@affected_tables`.** The diff is only as good
as the set of tables it watches, so don't hand-pick a subset per call — that is
how a test ends up watching `UserAccount` but silently missing the `UserSession`
and `StoredEvent` the same login created. Instead declare a module attribute
`@affected_tables` listing _every_ table the use case can affect — the ones it
writes **plus** the adjacent ones it must leave alone (e.g. `UserAccount` in the
login-link tests, to pin that creating a link never creates an account) — and
pass it to **every** `count_rows/@affected_tables` snapshot in the file. Then
each test only spells out the non-zero deltas; every other watched table is
asserted unchanged for free, and adding a table to the list retroactively
strengthens every test. Always include `StoredEvent` in `@affected_tables` for a
use case that emits events (the snapshot complements, it does not replace, the
exact event assertions). This applies to **every** test that invokes the use
case, including not-found/no-op paths — they snapshot `@affected_tables` and
assert `assert_no_row_count_diff/1`, so even an early-return path is pinned not
to write.

Use the diff for the **count**; keep asserting the **contents** of a specific
row by exact equality (and a specific deletion by "this row no longer exists",
e.g. `refute Repo.exists?(from r in Schema, where: r.id == ^id)`), since a count
diff cannot pin a row's fields.

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

**The use case is the only place that reads the clock.** `Clock.now/0` is
resolved once at the top of the use case and threaded down into the schema
changeset builders (`Schema.new(data, now)`, `Schema.update(record, data, now)`)
and event constructors — exactly as the class use cases do. A schema changeset
function or a delete/import path that calls `DateTime.utc_now/0` for itself
defeats the injected clock: its timestamps cannot be pinned, so the test cannot
assert them. Thread the clock from the use case so every persisted and emitted
timestamp can be asserted exactly.

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

**Pin the resource id in every broadcast pattern — PubSub is not sandboxed.**
Unlike the SQL sandbox, `Phoenix.PubSub` is process-global: a broadcast to a
**shared topic** (e.g. a context-wide `"classes"` topic that every list view
subscribes to) is delivered to _all_ subscribed processes, including other
`async: true` tests running concurrently. So a bare `assert_receive
{:class_updated, class, _}` can bind another test's leaked broadcast, and a bare
`refute_received {:class_updated, _, _}` can fail on one — both flaky, and both
worsen as more tests publish the same message. Make the patterns **selective**
by pinning the resource id the test owns (a unique UUID):

```elixir
assert_receive {:class_updated, %Class{id: ^id} = broadcast, _ref}
# …
refute_received {:class_updated, %Class{id: ^id}, _ref}
```

`assert_receive` then skips messages for other ids and waits for this test's own
(which is delivered synchronously, so it is already in the mailbox), and
`refute_received` ignores other ids entirely. This keeps the positive assertions
on _both_ the resource-specific and shared topics exact while staying race-free.
On a failure path where **no resource id exists** (a rejected create, an
unknown-id not-found), there is nothing to pin and no reliable refute on a
shared topic — rely on `assert_no_stored_events!/0` instead: the use case
broadcasts only after its transaction commits, so no stored event already proves
no broadcast.

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

- no rows created or removed — snapshot `@affected_tables` before the call and
  assert `assert_no_row_count_diff/1`, plus the exact-equality content check on
  any specific fixture row that must stay unchanged (`persisted == original`).
  Do this on _every_ rejected path, including early-return not-found cases
  (where the snapshot is mostly empty but still pins that the early return wrote
  nothing);
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

**Self-service (non-root) authorization needs a persisted principal.** When a
use case authorizes an action against the principal's _own_ record (a student
confirming their own username, an owner editing their own resource) rather than
a blanket root check, the policy matches on the link between the principal and
the entity — so the test must persist that link in the database, not just build
an `authentication/1`. The recipe: insert the owned record, insert the linking
projection row (e.g. the course `User` over `user_accounts`) so that its ID
equals the principal ID and it points back at the record (and the record points
back at it), then build `authentication(principal_id: <that id>, root: false)`.
A root principal still has to be persisted too if the use case loads the account
_before_ the policy's root short-circuit — otherwise the load fails closed.
Drive every distinct principal: the owner (succeeds), a _different_ non-root
principal (rejected), a root principal (per the policy), and a principal with no
linked record at all.

**Assert masked errors explicitly — once per upstream cause.** A use case often
collapses several distinct failures — access denied, "not a user", "not found" —
into one opaque error (e.g. `:student_not_found`) so it never leaks whether a
record exists or who owns it. A single not-found test does not prove the masking
holds: drive **each** upstream condition separately (a wrong owner, a missing
account, an unknown ID, a malformed ID) and assert they all return the same
masked result, each with no side effects. This is also where copy-paste bugs in
the masking surface — an `else` clause matching the wrong action atom, or a `=`
where a `<-` was meant, only fails when the masked branch is actually exercised.

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

**Side-effect-free `validate_*` companions need a failing case too.** Many
commands ship with a sibling `validate_*` function that a live form calls on
every keystroke: it builds and returns the changeset without committing (`{:ok,
changeset}`, or the bare changeset for a create — the errors live _in_ it, it
does not return `{:error, …}`). Test it from **both** directions, not just the
happy one: valid input yields a changeset with `errors_on/1 == %{}`, and one
representative invalid input yields a changeset carrying the exact expected
errors — both with no side effects. A "validate valid data" test alone passes
even if the function ignored its input entirely and always returned a clean
changeset; the failing case is what proves it actually runs the validation.

**Choosing the right changeset is a use-case concern.** Schemas usually expose
more than one changeset — commonly a create and an update one, with different
cast lists, defaults, or locking. The schema test covers what each changeset
does; proving the use case calls the _right_ one is the use-case test's job, and
it is asserted through the observable result, not by spying on the call. When
the distinction matters — a field settable on update but not on creation (or
vice versa), a default applied only on create, a version bumped only on update —
assert it: that the field is applied when it should be and ignored when it
should not, in the persisted row and the emitted event.

**Share rules common to several changesets; keep divergent ones separate.** When
two changesets (typically create and update) run the same validations, write
each rule once and generate one test per changeset with a `for` comprehension
that `unquote`s the variant into each `test`, dispatching through a small
private builder. This stays DRY _and_ granular — a failure names both the
variant and the rule (see [`class_test.exs`][class-test] /
[`student_test.exs`][student-test]):

```elixir
for variant <- [:new, :update] do
  describe "#{variant} value validations" do
    test "the name cannot be longer than 50 characters" do
      assert errors_on(changeset(unquote(variant), name: String.duplicate("a", 51))) ==
               %{name: ["should be at most 50 character(s)"]}
    end
  end
end

defp changeset(:new, overrides), do: :class_data |> build(overrides) |> Class.new(@now)
defp changeset(:update, overrides), do: :class |> insert(now: @now) |> Class.update(build(:class_data, overrides), @now)
```

Only put rules that validate a _provided_ value in the shared loop. Two things
do **not** belong there: `validate_required`, which cannot fail on the update
path (an omitted field keeps the persisted value), and any rule that diverges
between the changesets (uniqueness self-exclusion, a stricter create-only
format). Those get their own plain `describe` blocks per variant.

**Assert a changeset's effect as the whole applied struct, not field by field.**
A changeset-producing schema function (`new_*`, `link_*`, `create_or_update`, …)
is pinned by `Changeset.apply_changes/1` followed by **one exact-equality
assertion on the resulting struct** — every field at once, with `not_loaded/2`
for associations the function leaves unset and the generated `id`/token bound
from the result (see [Generated identifiers](#generated-identifiers)).
`apply_changes` resolves an association set through `change/2`/`put_assoc` back
to its struct, whereas the raw `changes` map stores it as a nested
`%Ecto.Changeset{}`, so the applied struct is both the more exact and the more
readable assertion. For an **update** changeset, reload the row first
(`Repo.get_by!`/`Repo.reload!`) and assert `apply_changes(changeset) ==
%{reloaded | changed_field: …}`: that pins the touched fields _and_ proves every
other field untouched in a single assertion. A no-op changeset asserts
`changeset.changes == %{}`.

**Optimistic locking is observed through the changeset's filters, not a
change.** `optimistic_lock(field)` does **not** put the bumped value into the
changeset's `changes` — it records the **current** value in `changeset.filters`
and applies the increment only at `Repo.update` time. So a schema test asserts
`changeset.filters == %{version: 2}` (or `%{active: true}` for a boolean-toggle
lock); the conflicting-update behaviour itself — a stale write raising
`StaleEntryError` — is a DB-backed concern covered by the use case that commits
the changeset, not the schema test. The same holds for
`unsafe_validate_unique_*` self-exclusion queries: assert the rejection
(`errors_on/1` carries `"has already been taken"`) by inserting a
**conflicting** row, since the query runs against the real `Repo` under
`DataCase`.

### Testing pure predicate functions over a date window

A schema may expose a pure boolean predicate — `active?(record, now)` on
`UserGroup`, `PreregisteredUser`, and `UserAccount` — that decides membership of
an inclusive `[start_date, end_date]` window. This is the in-memory sibling of
the query-level [windowed read](#testing-read-use-cases): same boundary
thinking, but tested by calling the function on `build`-only fixtures (no
database) rather than asserting a query's result set. Cover the **whole boundary
matrix**, one case per branch: the disabling flag short-circuits regardless of
dates; no bounds is always in; before the start is out; **on the start is in
(inclusive)**; strictly within is in; **on the end is in (inclusive)**; after
the end is out; and the start-only and end-only open-ended windows. For a
composite predicate (`PreregisteredUser.active?` is `active and
UserGroup.active?`), drive each factor independently so both halves are pinned.

One gotcha worth a case of its own: an in-memory predicate and its query
counterpart may compare at **different granularities**. `UserGroup.active?/2`
does `DateTime.to_date(now)` and compares **dates**, whereas the parallel
`where_user_group_active/1` compares the raw `DateTime` against the date column
— so a fixture that lands between midnight and `now`'s time of day can disagree
between the two. Pin the boundary at the granularity the function under test
actually uses. A worked example is [`user_group_test.exs`][user-group-test].

### Testing create-or-update (upsert) changesets

Some schemas expose a single function that returns **either** an insert or an
update changeset depending on whether a matching row already exists
(`SwitchEduId.create_or_update/2` keys on `swiss_edu_person_unique_id` via
`Repo.get_by`). Unlike a pure changeset, it reads the database, so it runs under
`DataCase`, and it has **two structurally different branches** to drive
separately:

- **No existing row** → the insert branch. Build the input with a factory, call
  the function, and assert the whole applied struct: the new-record defaults
  (fresh `id`, `version: 1`, all of `created_at`/`updated_at`/`used_at` at the
  injected instant) plus the cast data.
- **Existing row** → the update branch, plus any **conditional touch**.
  `create_or_update` bumps `used_at` on every login but only bumps `updated_at`
  when the identity's name actually changed. Reload the row and assert the whole
  applied struct as a diff from it, in two cases: name-changed →
  `%{reloaded | first_name: …, updated_at: now, used_at: now}` (**both**
  timestamps move), and name-unchanged → `%{reloaded | used_at: now}`, which pins
  the held `updated_at` and the unchanged names in one assertion. Assert the
  version filter from the optimistic lock on both.

A worked example is [`switch_edu_id_test.exs`][switch-edu-id-test].

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

### Testing delete use cases

A delete use case has **no input fields to vary**, so unlike a create or update
it gets a **single** happy-path test — add a second only where deletion
behaviour genuinely differs (e.g. an owned association that is sometimes blank,
sometimes populated). That test still makes the full set of assertions from the
[checklist](#what-a-business-layer-test-must-assert), with two delete-specific
emphases:

- **Assert the specific rows are gone, including owned/cascaded associations.**
  A delete's characteristic failure mode is leaving children behind, so assert
  the deleted row _and_ every row it owns no longer exist (`refute
Repo.exists?(from r in Schema, where: r.id == ^id)`), and pin the counts with
  a diff (`%{Schema => -1, OwnedSchema => -1, …}`) so exactly those rows were
  removed and nothing else. In the class case the use case deletes the
  expected-server-properties row explicitly — the foreign key is on the
  `classes` table, so a missing delete would orphan it — and the test pins that
  both rows are gone.
- **Assert the deletion event, but do not reconstruct a row from it.** A
  deletion event is intentionally **minimal** — it carries only the deleted
  entity's identity (id and name), enough to know _what_ was removed — so the
  [reconstruct-the-row-from-the-event](#exact-assertions-on-database-side-effects)
  rule does not apply: there is no row left to rebuild. Assert the event whole
  (stream, type, payload, metadata, `occurred_at`) and, separately, that the
  rows are gone. The event's `version` is the entity's current version (a delete
  does not bump it), so derive it from the inserted baseline rather than
  assuming `1`.

The branch tests cover the rest:

- **Constraint-blocked delete.** A delete guarded by a database constraint (a
  foreign key, e.g. "a class with servers cannot be deleted") is a **DB-backed
  branch** like a uniqueness check: build the blocking state (insert a row that
  references the target), assert the exact domain error the use case maps the
  constraint to, and assert the whole transaction rolled back — nothing deleted,
  no event, no broadcast. Setting up the blocking row may require fixtures from
  another context (a class-blocking server needs an owner and its
  server-properties rows); that cross-context coupling is real and worth the
  fixture.
- **Not found** and **authorization**, exactly as for an update: an unknown id
  returns the not-found error with no side effects (and, when not-found is
  reported before the authorization check, an unauthorized caller gets not-found
  too), and an unauthorized principal is rejected with no side effects.

A worked example is [`delete_class_test.exs`][delete-class-test]. Writing it
surfaced the same recurring gap as the create/update/read spikes: `DeleteClass`
stamped the deletion event with `DateTime.utc_now()` instead of the injected
clock, so the event's `occurred_at` could not be pinned; it now uses
`Clock.now()`.

### Testing sub-aspect (child-association) update use cases

Some update use cases do not update a record's own fields but a **child
association** of it — and bump the **parent's** `version`/`updated_at` as part
of the same transaction — while **returning the child**. `UpdateClass` rewrites
the class's columns; `UpdateExpectedServerPropertiesForClass` rewrites the
class's expected-server-properties association and returns those properties. The
[update strategy](#testing-update-use-cases) still applies, with the axes
shifted onto the child:

- **The three happy-path tests vary the child's fields.** "Update everything"
  (start from a blank child, set every field), "clear every optional" (start
  from a full child, reset every field), and a random one — exactly the
  update-testing trio, applied to the association's fields.
- **Assert both the returned child and the untouched parent.** Assert the
  returned child struct whole, _and_ separately assert the parent: its `version`
  bumped, its `updated_at` advanced to the pinned instant, and **every other
  parent field equal to the original**. That last assertion is the point of a
  sub-aspect update — it must change the child and the parent's metadata and
  _nothing else_ — so pin it (the worked example asserts the persisted class
  equals the original with only `version`, `updated_at` and the child replaced).
- **The audit event embeds a denormalized parent reference.** A child-update
  event typically carries a small `{id, name}` snapshot of the parent plus every
  child field; assert it whole like any other event. Both parent-reference
  fields are unchanged by a child-only update, so they equal the original's.
- **Existence-masking on the mutation.** When the use case masks an
  authorization failure as not-found (so it cannot leak the existence of a
  resource the caller may not see), assert the unauthorized caller gets the
  exact not-found result — not a raise — with no side effects. A
  side-effect-free `validate` sibling must mask **consistently** with its
  committing counterpart.

A worked example is
[`update_expected_server_properties_for_class_test.exs`][update-expected-properties-test].
Writing it surfaced two latent bugs the earlier spikes' patterns predict:
`Class.update_expected_server_properties` stamped `updated_at` with
`DateTime.utc_now()` instead of the injected clock (fixed by threading `now`, as
for `Class.update`), and the use case's `with/else` did not pass `{:error,
:class_not_found}` through, so any unknown ID crashed with a `WithClauseError` —
caught only because the not-found branch was finally tested.

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

The web layer is the LiveViews, components, and controllers under
`lib/archidep_web/…`. Its tests run under
[`ArchiDepWeb.Support.LiveCase`][live-case] (LiveViews and components) or
[`ArchiDepWeb.Support.ConnCase`][conn-case] (controllers and request tests).
Unlike the business layer, these tests do **not** touch the database or the real
use cases: every context is replaced by its [`Hammox`][hammox] mock
(`Accounts.ContextMock`, `Course.ContextMock`, …), so a web test exercises
_only_ the web layer — rendering, event handling, redirects — against canned
context responses. The business logic itself is proven separately under
`DataCase`.

The canonical worked example is [`profile_live_test.exs`][profile-live-test].

### What a web-layer test asserts — two kinds of output

The guiding principle from the top of this guide still holds: pin the entire
_observable_ behaviour. But a LiveView produces two very different kinds of
observable output, and they get different treatment:

1. **Exact-value outputs** — everything whose value the test fully controls and
   that is _not_ incidental markup: the rendered **page title**, **flash
   messages** and notifications (message _and_ type), **pushed events**
   (`push_event`), **redirects** (target path and flash), **PubSub broadcasts**
   the LiveView itself emits, the **mock interactions** (each context function
   called the expected number of times with the expected arguments), and the
   **data values** the page displays (a formatted date, a username, an IP).
   These are asserted **exactly, by whole-value equality**, exactly as in the
   business layer. There is no excuse to be loose here: a flash message is a
   known string, a pushed event is a known map.

2. **DOM structure** — the HTML tags, attributes, CSS classes, and nesting that
   carry those values. This is **not** asserted exactly. See below.

### Asserting the DOM: a meaningful projection, not exact markup

We deliberately do **not** assert an exact DOM tree. The markup is incidental:
which wrapper `<div>` holds a value, which Tailwind classes style it, how deeply
it nests — none of that is behaviour, and pinning it makes every styling tweak
break unrelated tests, which trains everyone to update assertions blindly and
destroys their signal.

What a test _does_ care about is that the page **works as intended**: the right
information is shown, and the right interactive affordances are present in the
right state. So assert a deliberately-chosen **semantic projection** of the
DOM — just enough to prove that — and nothing about the structural envelope
around it.

"Just enough" is not licence to assert a convenient subset and move on — that is
the [partial-assertion](#exact-assertions-on-return-values) failure mode the
business layer forbids, and it rots the same way. The discipline that keeps a
projection honest:

- **Anchor on stable, semantic selectors.** Target IDs (`#current-sessions`),
  ARIA roles, `data-*` hooks, and meaningful component classes
  (`.delete-session`), plus positional selectors that encode _meaning_
  (`tr:nth-child(2)` for "the second session"). Never anchor on incidental tag
  names, utility CSS classes, or deep structural paths — those are exactly the
  things we are refusing to pin.
- **Once you choose a projection, assert it wholly.** If the projection is "the
  rows of the sessions table", extract _every_ row and assert the **full list by
  equality** — not "a row exists matching …". Within each row, pin every cell
  the behaviour concerns. Do not wildcard a value you actually care about; if a
  cell is genuinely irrelevant to the behaviour under test, prefer to _project
  it out_ (don't extract it) rather than extract it and match it with `_`, so
  the shape of the assertion documents what matters. A bound wildcard in the
  middle of a tuple is a value silently going unchecked — the diff self-audit in
  [`AGENTS.md`](../../AGENTS.md) flags these.
- **Presence and absence are both assertions.** Assert that an affordance that
  _should_ render does, with the right label and state (the Delete button on a
  deletable session); and assert that one that should _not_ render is **absent**
  (no Delete button on the current session; no Change-username button until the
  username is confirmed). `has_element?/2` and `refute has_element?/2` are the
  tools — an element merely existing is not enough; its absence on the negative
  branch is what proves the `:if` guard.

The net effect: a change in _behaviour_ (a column drops, a button appears on the
wrong row, a flash goes missing) fails a test; a change in _markup_ (a restyle,
a re-nest) does not. That is the line — exact where we own the value,
structural-minimal where we do not.

### Tools

- **Prefer LiveViewTest's own semantic helpers** where they suffice: `element/2`
  with `render_click/2`, `render_submit/2`, `render_change/2` to drive
  interactions; `has_element?/2` for presence/absence; `render(view) =~ text`
  for a quick content check. These select by CSS selector and never make you
  handle raw markup.
- **Reach for the HTML helpers** in
  [`ArchiDepWeb.Support.HtmlTestHelpers`][html-test-helpers] when you need to
  extract _structured, multi-value_ content — a table into rows-of-cells — and
  assert it as one value: `find_html_elements/2` (returns each match as its own
  document, so you can map over matches and query within each),
  `html_element_text/1` (normalized text content), and `assert_html_title/2`.
  HTML is parsed with [LazyHTML][lazy-html] — the engine LiveView itself uses.
- `current_sessions_table/1` in the exemplar shows the pattern: select the table
  by id, map each `tbody tr` to a tuple of its meaningful cells, and assert the
  **whole** list of rows by equality — a complete projection of one component,
  anchored on a stable id.
- **Project a cell's visual state to a semantic value.** When a cell's meaning
  is carried by styling (an expiry badge that is `badge-error` / `badge-warning`
  / `badge-success`), don't pin the CSS class — derive the _meaning_ and assert
  that: the exemplar's `expiration_state/1` maps the badge to `:expired` /
  `{:soon, text}` / `{:ok, text}`, which becomes one field of the row tuple. The
  test then breaks if the highlight is wrong, not if the palette is restyled.

### Mounting, auth, and mocking contexts

- **Use the shared auth fixtures.** `setup :register_and_log_in_root` /
  `:register_and_log_in_student` (in [`ConnCase`][conn-case]) replace `:conn`
  with an authenticated connection and add `:auth`, `:session`, `:user_account`
  (and `:student` for the student fixture); `conn_with_auth/2` builds one for an
  explicit session. Drive **each principal the LiveView branches on** (root vs.
  student, and — where the UI differs — owner vs. other), asserting the
  projection that distinguishes them, not merely that the page mounts.
- **Mock every context call the mount and interactions make**, and pin the
  **call count**. With `setup :verify_on_exit!`, an `expect(Ctx.Mock, :fun, n,
fn … end)` asserts the function is called exactly `n` times with matching
  arguments — a real assertion about the LiveView's data dependencies. Counts
  above one are normal: a LiveView mounts twice (the disconnected HTTP render,
  then the connected socket), so a value read on every mount is fetched twice.
  Pin the argument too (`fn ^auth -> … end`).
- **Anonymous access redirects to login.** Use
  `assert_live_anonymous_user_redirected_to_login/2` (in
  [`LiveCase`][live-case]), which covers the no-token, invalid-session-token,
  and invalid-remember-me-cookie cases in one call.
- **Control time through the injectable clock**, exactly as the [business
  layer](#deterministic-time-via-an-injectable-clock) does. A LiveView that
  renders time-dependent output (relative "_n_ ago", remaining durations, an
  expiry badge) must read the current time from `ArchiDep.Clock`, not
  `DateTime.utc_now/0`. [`LiveCase`][live-case] installs a default
  `ArchiDep.Clock.Mock` → `SystemClock` stub (mirroring [`DataCase`][data-case])
  so tests that don't care about time still render; a test that asserts
  time-dependent output pins a fixed instant with `stub(ArchiDep.Clock.Mock,
:now, fn -> @now end)` and builds its fixtures at fixed offsets from `@now`,
  so every rendered date, duration, and badge state is deterministic and
  pinnable.

### Forms, validation, and interactions

A LiveView form is driven through its events, and **both** directions are
asserted:

- **`render_change` (validation).** Submit invalid input and assert the rendered
  form surfaces the expected validation error (the message text, projected from
  the DOM), and that valid input clears it. The exhaustive per-rule coverage
  lives in the form schema's own changeset test (as in the [business
  layer](#changeset-and-validation-errors)); the LiveView test pins only that
  the form is _wired_ — it calls the validation and renders its result.
- **`render_submit` (the action).** On success, assert the observable result:
  the success **flash/notification** (exact message and type), any **pushed
  event** (e.g. the `execute-action` that closes a dialog), and the post-submit
  form state. On failure, assert the error is rendered (the mocked context
  having returned `{:error, changeset}`). Build that error changeset by
  **casting the params and giving it an action** (e.g. via
  `Changeset.apply_action/2`): the form renders a field's errors only once the
  field is "used" (`Phoenix.Component.used_input?/1`), so a bare
  `Changeset.change/1` with an added error renders nothing — mirror the
  cast-with-action changeset the real context returns.

### Flash, notifications, and PubSub-driven updates

- **Flash and notifications are exact.** Assert the message string and its
  `type` (`:success`, `:warning`, `:error`) by equality. When the notification
  is delivered asynchronously to the socket, `wait_for_socket_assigns!/3` (in
  [`LiveCase`][live-case]) waits for the flash to match rather than racing on
  it.
- **PubSub-driven re-renders are behaviour.** When a LiveView subscribes to a
  topic and updates on a broadcast (the profile page refreshes the student on
  `{:student_updated, …}`), test it: broadcast the message to the topic the
  LiveView subscribed to, then assert the re-rendered projection reflects the
  change. These topics are keyed by resource ID, so the assertion is naturally
  selective and safe under `async: true` (see the [business-layer PubSub
  note](#asserting-pubsub-broadcasts) on pinning the ID).

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
function components with the [LazyHTML][lazy-html]-based
[`HtmlTestHelpers`][html-test-helpers]._

[contributing]: ../CONTRIBUTING.md#testing
[data-case]: ../test/support/data_case.ex
[telemetry]: ../test/support/telemetry_test_helpers.ex
[exemplar]: ../test/archidep/accounts/log_in_or_register_with_switch_edu_id_test.exs
[create-class-test]: ../test/archidep/course/create_class_test.exs
[update-class-test]: ../test/archidep/course/update_class_test.exs
[read-classes-test]: ../test/archidep/course/read_classes_test.exs
[delete-class-test]: ../test/archidep/course/delete_class_test.exs
[update-expected-properties-test]: ../test/archidep/course/update_expected_server_properties_for_class_test.exs
[class-test]: ../test/archidep/course/schemas/class_test.exs
[student-test]: ../test/archidep/course/schemas/student_test.exs
[user-group-test]: ../test/archidep/accounts/schemas/user_group_test.exs
[switch-edu-id-test]: ../test/archidep/accounts/schemas/identity/switch_edu_id_test.exs
[ex-unit]: https://hexdocs.pm/ex_unit/ExUnit.html
[ex-unit-doctests]: https://hexdocs.pm/ex_unit/ExUnit.DocTest.html
[gen-server]: https://hexdocs.pm/elixir/GenServer.html
[ex-machina]: https://hexdocs.pm/ex_machina/readme.html
[faker]: https://hexdocs.pm/faker/readme.html
[hammox]: https://github.com/msz/hammox
[mox]: https://hexdocs.pm/mox/Mox.html
[live-case]: ../test/support/live_case.ex
[conn-case]: ../test/support/conn_case.ex
[html-test-helpers]: ../test/support/html_test_helpers.ex
[profile-live-test]: ../test/archidep_web/profile/profile_live_test.exs
[lazy-html]: https://hexdocs.pm/lazy_html
