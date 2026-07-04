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
  - [Testing components: through the page or in isolation](#testing-components-through-the-page-or-in-isolation)
  - [Pure helpers on a LiveView or component](#pure-helpers-on-a-liveview-or-component)
- [Channels](#channels)
  - [Connect and authentication: drive `connect/3` through the handler](#connect-and-authentication-drive-connect3-through-the-handler)
  - [The pushed-events projection: the channel's whole-value contract](#the-pushed-events-projection-the-channels-whole-value-contract)
  - [Mocking, subscriptions, principals, and time](#mocking-subscriptions-principals-and-time)
- [Plumbing (router, plugs, auth)](#plumbing-router-plugs-auth)
- [Helpers & components](#helpers--components)
  - [Pure helper modules](#pure-helper-modules)
  - [Stateless function components](#stateless-function-components)
- [Runtime processes (GenServers, GenStage)](#runtime-processes-genservers-genstage)
- [Testing external-tool compatibility](#testing-external-tool-compatibility)

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
- **Avoid sharing data between tests.** Two tests that read the same literal
  fixture data are coupled in a non-obvious way: change it for one and the other
  may silently start passing for the wrong reason, or fail. Each test should own
  its inputs. Prefer **inlining** a test's data at its call site (ideally using
  _different_ values from neighbouring tests, so an accidental cross-wiring is
  visible), or generating it with a **factory** that randomizes the irrelevant
  fields and pins only what the test asserts. What is fine: a helper that
  _builds_ a fixture (random with some pinned overrides) — that is reuse of a
  generator, not of data; and a small, intuitive shared constant like `@now` /
  `@past` used sparingly. What is not fine: a module-level `defp some_params`
  whose exact contents a handful of tests both feed in _and_ assert against, or
  a second helper holding the _expected_ result — both pull the tests' fates
  together. If a value is used in exactly one test, define it in that test, not
  at module scope.

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
of the system subscribe to them — so they are asserted like any other output, by
**whole value**.

A single use case often broadcasts the _same_ message to **several** topics (a
global topic, a per-group topic, a per-owner topic). Subscribing the test
process to all of them funnels every message into one mailbox, where they can no
longer be attributed to the topic that delivered them: a double broadcast on one
topic with none on another is indistinguishable from one broadcast each. So
subscribe each topic in its **own collector** with
[`ArchiDep.Support.PubSubTestHelpers`][pub-sub-test-helpers]:
`collect_broadcasts/1` runs the real subscribe call in a dedicated process
(mirroring production, where each consumer subscribes to exactly one topic), and
`received_broadcasts/1` returns the exact list of messages that reached that one
topic. Set up the collectors _before_ invoking the use case, then assert each
topic's list by whole-list equality:

```elixir
broadcasts = %{
  new: collect_broadcasts(fn -> PubSub.subscribe_server_created() end),
  group: collect_broadcasts(fn -> PubSub.subscribe_server_group_servers(group.id) end),
  owner: collect_broadcasts(fn -> PubSub.subscribe_server_owner_servers(owner.id) end)
}

# … invoke the use case …

assert received_broadcasts(broadcasts.new) == [{:server_created, server}]
assert received_broadcasts(broadcasts.group) == [{:server_created, server}]
assert received_broadcasts(broadcasts.owner) == [{:server_created, server}]
```

The whole-list `==` covers both halves of the contract at once — the exact
payload _and_ that the topic received exactly that, no duplicate and nothing
extra. Assert on _every_ topic the use case is expected to publish to.

`received_broadcasts/1` needs no timeout and never races: local PubSub delivery
is synchronous (the default PG adapter `send`s to local subscribers inside
`broadcast/3`), so by the time the use case returns every message is already in
the collector's mailbox, and the drain is a synchronous round-trip behind them.

**Topics are isolated per test.** Unlike the SQL sandbox, `Phoenix.PubSub` is
process-global — a broadcast reaches every subscribed process, including other
`async: true` tests. Two mechanisms keep this race-free, both transparent as
long as you subscribe and broadcast through the context `PubSub` facade:

- **Keyed topics** (`"classes:#{id}"`, `"servers:#{id}"`, …) carry a per-test
  UUID in the topic name, so a subscriber only ever sees its own resource.
- **Global, non-keyed topics** (`"classes"`, `"servers:new"`) are suffixed per
  test by [`ArchiDep.PubSub.Scope`][pub-sub-scope] (`global_topic/1`), which the
  `DataCase` / `LiveCase` / `ChannelCase` setups stub with a unique value for
  each test — so concurrent tests never observe each other's broadcasts on a
  shared topic. In production the suffix is empty and the topic keeps its global
  name.

On a failure or no-op path, assert each subscribed topic stayed silent —
`received_broadcasts(c) == []`. Where the path has no resource to subscribe to
at all (an early not-found return, before any id exists),
`assert_no_stored_events!/0` carries the proof instead: the use case broadcasts
only after its transaction commits, so no stored event already implies no
broadcast.

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
- no PubSub broadcast — `received_broadcasts(c) == []` on every topic the path
  subscribed to (see [above](#asserting-pubsub-broadcasts)); an early not-found
  return with no topic to subscribe to relies on `assert_no_stored_events!/0`
  instead, since a broadcast follows only a committed event;
- no telemetry event emitted (attach a handler beforehand, then refute).

**For telemetry, prefer `refute_received` over `refute_receive`.**
`refute_receive` blocks for its full timeout (100 ms by default) on _every_
call, which taxes a large async suite; `refute_received` checks the mailbox
instantly. Instant checking is not merely faster here, it is **correct**,
because the event is delivered _synchronously, before the use case returns_:
`:telemetry.execute/3` runs handlers synchronously in the calling process, and
our handler `send`s to the test process before returning. So once the
(synchronous, in-process) use case has returned, the mailbox is settled — a
message cannot arrive later — and `refute_received` cannot race. PubSub absence
is checked in the same spirit but through the collector's
`received_broadcasts(c) == []`, which exploits the same synchronous local
delivery.

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
- **Project the whole page state, not one region in isolation.** A page that
  shows mutually-exclusive regions (a welcome banner _or_ a call to action _or_ a
  list of cards, plus dialogs) must be asserted through a **single projection
  that covers every region at once** — e.g. a map `%{welcome: …, call_to_action:
…, servers: …}` asserted by equality. A test that only checks its own region
  cannot catch a conditional-logic bug that makes another region render when it
  should not (a call to action leaking onto a page that already has servers).
  This rules out the lazy shortcut of a free-floating `something_shown?(html)`
  boolean helper called in just one test: fold each such check into the page
  projection as a field (`call_to_action: :student | :root | nil`, not
  `call_to_action_shown?: true`), and assert the whole projection in **every**
  render test of that page. A region's value must distinguish its meaningful
  variants (the root call to action vs. the student one are different states, so
  the projection must tell them apart), and a value the page is responsible for
  displaying (the SSH key fingerprints, not just their section heading) must
  appear _in_ the projection — checking that a title is present while ignoring
  the data under it is the partial-assertion failure mode again.
- **Asserting translated text: re-call `gettext` for simple messages, pin the
  literal for complex ones.** For a short message whose interesting part is an
  interpolated value, build the expected string by re-calling the same `gettext`
  with the same bindings (`gettext("Created class {class}", class: "New
Class")`) — it stays in sync and verifies the wiring and the interpolated
  value, which is what the page controls. But for a message carrying
  **resolution logic** (an ICU `plural`/`select`, as in the delete-class
  dialog's "1 server"/"# servers" warnings), re-calling `gettext` with the same
  args only asserts `gettext(x) == gettext(x)`: it proves the msgid and count
  are wired, but the wording and the plural branch are resolved identically on
  both sides and go unverified — and it duplicates a long, opaque ICU template
  in the test. Assert the **exact resolved literal** instead ("…because 1 server
  is linked to it…"): it is a true independent oracle (a typo, wrong plural
  branch, or wrong count fails it) and reads as the sentence the user sees.
  Confirm the literal by running the test rather than hand-resolving the plural.
  The same rule applies to flash/notification messages.

The net effect: a change in _behaviour_ (a column drops, a button appears on the
wrong row, a flash goes missing) fails a test; a change in _markup_ (a restyle,
a re-nest) does not. That is the line — exact where we own the value,
structural-minimal where we do not.

### Tools

- **Prefer LiveViewTest's own semantic helpers** where they suffice: `element/2`
  with `render_click/2`, `render_submit/2`, `render_change/2` to drive
  interactions; `has_element?/2` for presence/absence; `render(view) =~ text`
  only for an incidental string the page does not own (a static label). These
  select by CSS selector and never make you handle raw markup. A raw `render =~
value` is **not** an acceptable assertion for a value the page _renders_ (a
  username, a fingerprint, a count) nor for which region is showing — those go
  through the page projection asserted by equality. `=~` over the whole HTML
  string is the weakest possible check (it matches anywhere, including hidden or
  unrelated markup) and silently passes when the value lands in the wrong place.
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
  explicit session. Both fixtures also have a two-argument form
  (`register_and_log_in_root(context, overrides)`) for use **inside a test**
  (not as a `setup` hook) when you need to pin specific displayed values: the
  `overrides` keyword carries `:user_account`, `:session` and (for the student
  fixture) `:student` keyword lists merged into the respective factory builds.
  Reach for the override form instead of hand-rolling the whole authenticated
  graph — pin only the attributes the test asserts (a username, a registration
  date), and let the factory randomize the rest.
- **Drive every principal, and test the full page for both.** Drive **each
  principal the LiveView branches on** (root vs. student, and — where the UI
  differs — owner vs. other), asserting the projection that distinguishes them.
  Beyond that, every **full LiveView page** must be tested with **both** a root
  and a student principal even when the page currently renders identically for
  them: that the page mounts and renders for each principal is itself the
  behaviour under test, and pinning it guards the page against a future change
  that makes it principal-specific. (A component reused across pages need not
  repeat this if the pages embedding it already cover both principals.) Where a
  page **delegates authorization to the context** — admin pages have no
  root-only guard in the router or `on_mount`; the mocked context enforces
  access — the only principal the _web layer_ branches on is
  authenticated-vs-anonymous, so test it for **root** (renders) and
  **anonymous** (redirects to login); a student principal would only assert the
  mock's canned return and adds nothing at the web layer.
- **Mock every context call the mount and interactions make**, and pin the
  **call count**. With `setup :verify_on_exit!`, an `expect(Ctx.Mock, :fun, n,
fn … end)` asserts the function is called exactly `n` times with matching
  arguments — a real assertion about the LiveView's data dependencies. Counts
  above one are normal: a LiveView mounts twice (the disconnected HTTP render,
  then the connected socket), so a value read on every mount is fetched twice.
  Pin the argument too (`fn ^auth -> … end`).
- **Deep pages with child components: stub the ambient reads, `expect` only the
  action.** Pinning an exact call count (above) works when a page reads a value
  a fixed number of times. It breaks down on a page whose eagerly-rendered child
  `live_component`s also read context: the admin class detail page lists the
  class students three times per render — its own load plus the delete and
  import dialogs — and a child notification re-renders the parent, re-firing
  every child's `update/2`, so the count is variable and not the behaviour under
  test. There, `stub/3` the ambient reads (a stable canned return) and reserve
  `expect/4` for the single mutation the test asserts (the `update_class` /
  `delete_class` call). Corollary: to mount such a page you must satisfy
  **every** child component's `update/2`, including dialogs you are not testing
  — stub their reads too so the page renders.
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
- **Multi-field and nested-embed forms** are still only pinned for _wiring_.
  Beyond `render_change`/`render_submit`, assert that an embedded sub-item can
  be added: `render_click` the add button, then assert one more sub-field input
  is rendered — Phoenix renders a hidden tracking input per embed, so filter to
  the value input (`input[type="text"][name^="…"]`) when counting. The
  exhaustive per-rule validation of the form schema still lives in its own
  changeset test, not here.
- **Cover a create form with a minimal _and_ a full submission**, mirroring the
  business-layer [create strategy](#testing-create-use-cases) (there is no
  "random" web variant — the test controls the inputs). Submit once with only
  the **required** fields and once with **every** field filled (`render_click`
  to add any embedded sub-items first), and in each assert the **exact data map
  the context received**, by equality: capture it by having the mock forward its
  argument to the test (`send(test_pid, {:created_with, data})`) then
  `assert_receive`. The minimal submission proves the unfilled fields default
  correctly; the full one proves every field (including embeds) is wired. A mock
  matcher that pins only `%{name: …}` is a partial assertion — it lets the other
  fields go unchecked.
- **Cover an update form with a full _and_ a clear-every-optional submission** —
  the update analogue of the minimal/full create pair. Submit once changing
  **every** field, and once **clearing every optional** field (blank the dates,
  empty the fingerprints), asserting in each the **exact data map the context
  received**, by equality (captured the same way). The full submission proves
  every field is wired; the clear submission proves a blanked input serializes
  to `nil`/`[]` (Ecto casts an empty value to the field default) rather than
  silently keeping the prior value.
- **Pin the form's own state by projection.** When a test asserts the form's
  state rather than the context call (e.g. that closing a dialog resets it),
  project the editable field values into a map — input values via
  `html_element_attribute/2`, textareas via `html_element_text/1`, checkboxes by
  the presence of `checked`, embeds as the list of their value inputs — and
  assert the **whole map** by equality (populated, then blank), not a single
  field.

### Flash, notifications, and PubSub-driven updates

- **Flash and notifications are exact, asserted by projection.** A notification
  is a `Flashy.Normal` struct whose `component` field holds a render function,
  so it cannot be asserted by whole-value `==`; its `{type, message}` is the
  meaningful, comparable projection (the notification analogue of the
  DOM-projection discipline). `flash_notifications/1` (in
  [`LiveCase`][live-case]) returns the current notifications as `{type,
message}` tuples; assert the **whole list** by equality, message string and
  `type` (`:success`, `:warning`, `:error`) included. When the notification is
  delivered asynchronously to the socket, wait for the projection first with
  `wait_for_socket_assigns!/3` (which accepts the socket assigns, so
  `&(flash_notifications(&1) == [{:success, msg}])` is a valid predicate) rather
  than racing on it, then assert `flash_notifications(view)` by equality.
- **PubSub-driven re-renders are behaviour.** When a LiveView subscribes to a
  topic and updates on a broadcast (the profile page refreshes the student on
  `{:student_updated, …}`), test it: broadcast the message to the topic the
  LiveView subscribed to, then assert the re-rendered projection reflects the
  change. These topics are keyed by resource ID, so the assertion is naturally
  selective and safe under `async: true` (see the [business-layer PubSub
  note](#asserting-pubsub-broadcasts) on pinning the ID).
- **A list view on a _global_ topic is isolated per test, so assert the whole
  list.** Some list LiveViews subscribe to a shared, non-keyed topic (the admin
  classes list on `"classes"`, not a per-resource topic). That topic is scoped
  per test by [`ArchiDep.PubSub.Scope`][pub-sub-scope] (see the [business-layer
  note](#asserting-pubsub-broadcasts)), so a broadcast driven via the context's
  `publish_*` helper reaches only this test's view. After driving a
  create/update/delete, wait for the change in the socket assigns, then assert
  the **whole list** projection by equality — the same whole-value discipline as
  the mount-time full-list assertion.

### Testing components: through the page or in isolation

A LiveView component (`live_component`) can be tested through a parent page or
on its own with `live_isolated/3`. Choose by reuse:

- **Through its parent page** when the component is only ever embedded there and
  its behaviour is observable in the page's projection — as with
  `CurrentSessionsLive` on the profile page, whose rendering, `delete_session`
  event, and `update/2` are all driven via `live(conn, "/profile")`. This tests
  the real wiring (the assigns the parent passes, the PubSub subscriptions)
  without `live_isolated` ceremony, and is the default.
- **In isolation** (`live_isolated/3`) when the component is **reused across
  multiple pages** — test it once on its own, then assert only a wiring
  smoke-test in each parent, rather than re-testing the whole component through
  every page that embeds it — or when its internal branches are awkward to drive
  through a parent.

Pure helper functions on a component get isolated unit tests regardless of how
the component itself is tested (see below).

_The `live_isolated/3` mechanics will be settled against a real reviewed example
when the first genuinely reused component is tested; the principle above is the
decision rule until then._

### Pure helpers on a LiveView or component

A LiveView or component often exposes pure helper functions that carry real
logic — a threshold, a branch, a classification (e.g.
`CurrentSessionsLive.expired?/2` and `expires_soon?/2`, which compare a
session's expiry against a clock with a `< 0` and a `< 2 days` boundary). Split
their coverage exactly as the form-schema-vs-LiveView split above:

- **The helper's full logic and boundaries** are pinned in a **focused unit
  test** of the module (under plain `ExUnit.Case` when the helper touches
  neither the database nor processes), the same way a schema's changeset rules
  are pinned in the schema test. Cover each branch and each boundary exactly (at
  the threshold, one unit either side). See
  [`current_sessions_live_test.exs`][current-sessions-live-test].
- **The rendered page asserts only that the helper is wired** — that its
  resulting states actually appear (the expired / expiring-soon / fine badges in
  the sessions table), not the boundary matrix.
- **A helper that merely delegates to an already-tested function is not
  re-tested.** `CurrentSessionsLive.expires_at/1` just delegates to
  `UserSession.expires_at/1`, which the schema test already covers exhaustively,
  so it gets no separate test.

## Channels

The user socket and channel (`ArchiDepWeb.Channels.UserSocket` / `UserChannel`)
are tested with [`ChannelCase`][channel-case] (`Phoenix.ChannelTest`). Like the
LiveView and controller layers, channel tests are **web-layer citizens**: every
context is its [`Hammox`][hammox] mock (`Accounts.ContextMock`,
`Course.ContextMock`, `Servers.ContextMock`), the clock is injected, and
`verify_on_exit!` enforces the expectations — but `Phoenix.PubSub` is the
**real** server, because the channel's whole job is to react to broadcasts. The
worked examples are [`user_socket_test.exs`][user-socket-test] (the transport)
and [`user_channel_test.exs`][user-channel-test] (the channel).

### Connect and authentication: drive `connect/3` through the handler

The socket's `connect/3` is the authentication gate. Sign a token the way the
controller does — `sign_user_socket_token/2` (in [`ChannelCase`][channel-case])
wraps `Phoenix.Token.sign(@endpoint, "user socket", session_id)` — then drive
`connect(UserSocket, %{"token" => token}, connect_info: …)` and assert the whole
result by `==`: `{:ok, socket}` with `socket.assigns == %{auth: auth}` on
success, or the exact `{:error, reason}` on each rejection branch (missing /
non-string / unverifiable / expired token, and a verified token whose session is
gone). Mock `Accounts.validate_session_id/2` and pin its argument — the decoded
`session_id` and the `ClientMetadata` built from the `connect_info`. The token
itself is the [documented token exception](#plumbing-router-plugs-auth): forge
an expired one with `sign_user_socket_token(id, signed_at: <past>)` rather than
asserting ciphertext. `id/1` and `handle_error/2` are pure and asserted directly
(the socket id, and each error mapped to its HTTP status).

### The pushed-events projection: the channel's whole-value contract

The channel has no DOM and no `handle_in` — it is server-to-client push only, so
its observable contract is the **`join` reply plus the pushed events**, and
those get the same whole-value exactness the DOM projection gets in the web
layer. There is nothing incidental to project away here: a pushed payload is a
known map, so assert it **by `==`**, never `assert_push "session", _` for a
payload the test cares about.

- **The initial session data is the join _reply_, not a push.**
  `UserChannel.join/3` returns `{:ok, ClientSessionData}` and
  `send_updated_data/1` only _pushes_ `"session"` when the data **changes** from
  what was last sent. So a fresh join replies with the session data and pushes
  `"cloudServerData"`, but does **not** push `"session"`. Assert the reply
  struct by `==`, `assert_push "cloudServerData", payload` by `==`, and
  `refute_push "session", _`. Build each expected payload from the fixtures you
  control (pin every field), the same independent-oracle discipline the web
  layer uses for displayed values.
- **`refute_push` proves the dedup branches.** Because both push helpers skip
  when the projected payload is unchanged, a broadcast that does not change the
  data must produce **no** push — assert that absence with `refute_push`. A
  server event never changes the session data, so each server test asserts the
  new `"cloudServerData"` and `refute_push "session", _`; a student update that
  touches no displayed field refutes **both**. This is the channel analogue of
  the presence/absence discipline in the [DOM
  projection](#asserting-the-dom-a-meaningful-projection-not-exact-markup).
- **Identity filtering is enforced by the keyed topic, so the `handle_info`
  guards are defensive.** The channel subscribes only to its own keyed topics
  (`server-owners:<principal_id>:servers`, `students:<student_id>`,
  `classes:<class_id>`), so it only ever receives events whose owner/student/
  class id matches — the `principal_id`-pinned `handle_info` heads can never see
  a mismatch in practice. Tests therefore drive only **deliverable** messages
  (broadcast through the context's `publish_*` helper on the topic the channel
  subscribed to); do not hand-deliver an impossible mismatched message, which
  would only exercise an unreachable `FunctionClauseError`.

### Mocking, subscriptions, principals, and time

- **Pin the join's context reads by count and argument.** `expect` the join's
  `Servers.list_my_servers(^auth)` (once) and, for a student,
  `Course.fetch_authenticated_student(^auth)` (once); for a root user set **no**
  expectation on `fetch_authenticated_student`, so an erroneous call fails the
  test (root short-circuits to `student: nil`).
- **Prove a subscription behaviourally.** After joining, broadcast the matching
  event with the real `Course.PubSub` / `Servers.PubSub` `publish_*` helper and
  assert the resulting push — the channel analogue of [PubSub-driven
  re-renders](#flash-notifications-and-pubsub-driven-updates). The topics are
  id-keyed, so this is naturally selective and safe under `async: true`.
- **Drive both principals.** Cover a root (`student: nil`) and a student (the
  student sub-map), the same rule the web layer applies.
- **Control time through the injected clock.** [`ChannelCase`][channel-case]
  installs the default `ArchiDep.Clock.Mock` → `SystemClock` stub (mirroring
  [`LiveCase`][live-case]); a test that asserts active-server filtering pins a
  fixed `@now` with `stub(ArchiDep.Clock.Mock, :now, fn -> @now end)` and builds
  its servers at fixed offsets, so `Server.active?/2` is deterministic.

## Plumbing (router, plugs, auth)

Controllers and request-level plumbing are tested with
[`ConnCase`][conn-case] (`Phoenix.ConnTest`), driving real requests through the
endpoint and router so the pipeline plugs run. As in the LiveView layer, every
context is its [`Hammox`][hammox] mock, and the same exactness rules apply — the
worked example is [`auth_controller_test.exs`][auth-controller-test].

**Assert the whole observable response by `==`.** A request test pins every
output the action controls, exactly, the way a LiveView test pins its whole-page
projection:

- the **status** and, for a redirect, its **target** — `redirected_to(conn) ==
~p"/some/path"` (a redirect asserts both at once);
- the **session** keys the action sets or clears — `get_session(conn, :key)`;
- the **response cookies** it writes or deletes — `conn.resp_cookies[name]`,
  projected to the deterministic fields (a signed cookie's value is opaque, so
  assert its options and that the round-trip works where the value matters, not
  the ciphertext);
- the **flash notifications** — project the conn's flash to `[{type, message}]`,
  dropping the random keys `Flashy` assigns, and assert by `==` (the same shape
  the LiveView layer's `flash_notifications/1` produces);
- the **rendered body** — for HTML, a projection built with the
  [`HtmlTestHelpers`][html-test-helpers]; for JSON, `json_response/2` matched by
  `==`.

A non-deterministic security token in a response (a CSRF token, a signed socket
token) is the documented exception: assert it with
`assert_secure_random_token/1` (see [Generated
identifiers](#generated-identifiers)), or, when the token is verifiable, decode
it and assert the payload (e.g. `Phoenix.Token.verify/4` returning the expected
id).

**Drive both principals.** Use the shared auth fixtures
(`register_and_log_in_root` / `:register_and_log_in_student`) for the
authenticated cases and a plain `conn` for the anonymous one;
admin/authorization is delegated to the context, so at the web layer the
meaningful principals are root and anonymous.

**Plugs and the on_mount hook are tested through a route or a real mount, not by
calling them in isolation.** An authenticated `GET /login` redirecting is what
exercises the `fetch_authentication` + `redirect_if_user_is_authenticated`
round-trip; building a signed cookie with the `ConnCase` helpers
(`put_user_token_in_remember_me_cookie/2`, `put_user_token_in_session/2`,
`secret_key_base/0`) and hitting a route exercises the remember-me-cookie path;
and mounting the lightest authenticated LiveView with `live/2` exercises
`live_auth`'s on_mount, where `assert_push_event/3` pins the session data it
pushes. `assert_live_anonymous_user_redirected_to_login/2`
([`LiveCase`][live-case]) covers the anonymous-redirect branch across the suite.

## Helpers & components

Alongside the LiveViews and controllers, the web layer has standalone **helper
modules** (`lib/archidep_web/helpers/…`) and **stateless function components**
(`lib/archidep_web/components/…`). Both are mostly pure — a helper transforms
data, a function component renders attrs and slots to markup — so their tests
are correspondingly light. The worked examples are
[`auth_helpers_test.exs`][auth-helpers-test] and
[`core_components_test.exs`][core-components-test].

### Pure helper modules

A helper that touches neither the database nor processes is tested under plain
`ExUnit.Case, async: true` — no case template. Assert each clause and branch by
its exact return value (`assert`/`refute` on a boolean predicate pins the whole
value; `==` for any richer return), one test per branch.

- **Doctests are a legitimate form of coverage for a simple, self-evident pure
  function.** A doctest's `iex>` line and its expected output are a whole-value
  assertion that doubles as documentation, so a formatting helper whose
  behaviour is obvious from a couple of examples — e.g.
  [`date_format_helpers_test.exs`][date-format-helpers-test], which is a single
  `doctest` and nothing else — needs no separate ExUnit tests. Reach for
  explicit ExUnit tests when the helper has **branches or boundaries** to cover
  exhaustively (a predicate with several falsifying conditions, an off-by-one
  threshold), where a doctest would be an unreadable wall of examples;
  [`auth_helpers_test.exs`][auth-helpers-test] pins each branch of
  `can_impersonate?/2` that way.
- **A helper that merely delegates to an already-tested function is not
  re-tested.** `AuthHelpers.username/1` is a `defdelegate` to
  `ArchiDep.Authentication.username/1`, covered by that module, so it gets no
  test — the same rule the [LiveView/component helpers
  section](#pure-helpers-on-a-liveview-or-component) states.
- **A helper whose result is a side effect is pinned by that effect, not its
  return value.** `LiveViewHelpers.set_process_label/2` (and its `/3` arities)
  returns `:ok` and sets the OTP process label; the test reads it back with
  `:proc_lib.get_label(self())` and asserts the exact label string, one test per
  arity ([`live_view_helpers_test.exs`][live-view-helpers-test]). Each ExUnit
  test runs in its own process, so the label mutation is isolated.
- **A helper that builds a command struct, or takes a conn or socket, is still
  asserted whole.** `DialogHelpers.open_dialog/1` returns a
  `Phoenix.LiveView.JS` struct — assert the whole struct by `==`, since the
  command sequence is the contract (as
  [`server_components_test.exs`][server-components-test] does for `JS.push`). A
  conn- or socket-taking helper is driven with a built conn (`ConnCase`) or a
  minimal `%Phoenix.LiveView.Socket{}` and its whole returned value asserted by
  `==`: `ConnHelpers.conn_metadata/1` against a `%ClientMetadata{}`
  ([`conn_helpers_test.exs`][conn-helpers-test]), and
  `DialogHelpers.validate_dialog_form/4`'s resulting `form` assign across its
  apply / validate-ok / validate-error branches
  ([`dialog_helpers_test.exs`][dialog-helpers-test]).

### Stateless function components

A function component (`def x(assigns)` with `~H`) renders attrs and slots to
markup with no process or state. Render it in isolation under
[`LiveCase`][live-case] and assert a **semantic projection of the DOM by `==`**,
exactly as the [DOM projection
rule](#asserting-the-dom-a-meaningful-projection-not-exact-markup) governs page
output — the markup envelope is incidental, the rendered information is not. (A
component that is only ever embedded in, and observable through, a page is
covered through that page instead; see [Testing components: through the page or
in isolation](#testing-components-through-the-page-or-in-isolation).)

- **Render attr-only components with `render_component/2`; render slotted
  components through an `~H` template with `rendered_to_string/1`.** Passing
  slot content to `render_component/2` (its `inner_block` form) is unreadable,
  so write the component the way a caller would and render that:

  ```elixir
  # Attr-only — render_component/2 (as the existing component tests do)
  render_component(&CoreComponents.no_data/1, text: "n/a")

  # Slotted — rendered_to_string/1 with an ~H template
  assigns = %{}

  rendered_to_string(~H"""
  <CoreComponents.warning_note>Disk almost full</CoreComponents.warning_note>
  """)
  ```

- **Project to what the component is _for_, not how it is styled.** A component
  whose attrs only toggle Tailwind classes (`no_data/1`'s muted styling,
  `data_display_element/1`'s `small` font switch, the responsive grid on
  `data_display/1`) has no behaviour in those classes — assert the **displayed
  text / slot content** and do **not** pin spacing or layout classes.
  Manufacturing class assertions to chase coverage is forbidden, the same trap
  the DOM projection rule warns about.
- **Pin a class only when it is the semantic marker that distinguishes
  variants.** The `note-info` / `note-warning` class on the note components _is_
  the behaviour — it is what makes a warning a warning — so the note projection
  asserts its wrapper class tokens, the same way
  [`events_components_test.exs`][events-components-test] pins a badge's colour
  tokens. Exact where we own the value, structural-minimal where we do not.
- **Assert the `:global` passthrough contract.** Every component here accepts
  arbitrary HTML attributes via `attr :rest, :global` — pin that a
  caller-supplied attribute reaches the element (`no_data/1` rendered with `id:
…` carries it through), because that passthrough is a real behavioural
  contract, not incidental markup.

## Runtime processes (GenServers, GenStage)

The server-tracking and Ansible-pipeline modules are OTP processes —
[GenServer][gen-server]s, a GenStage producer/consumer, supervisors. Unlike the
business layer they cannot be exercised purely with `DataCase`; they need
process scaffolding (supervised processes, stubbed boundaries, drained
mailboxes). The techniques below are the reused ones; anything specific to a
single process (e.g. how `Ansible.Runner`'s subprocess output is faked, or how
an embedded `:queue` is normalized for equality) stays as a comment in that test
file.

- **Test the logic as a pure state machine; test the process for wiring.** Keep
  the substantive logic in a pure module or state struct and unit-test it by
  passing structs through its functions, asserting the **whole returned value by
  `==`** — fast, `async: true`, no process or database machinery. The
  GenServer/GenStage around it is thin glue; cover it with a small, separate
  process test that proves `init` and the `call`/`cast`/`info` dispatch are
  wired, not the logic again. The `ServerManagerState` and
  [`AnsiblePipelineQueue.State`][queue-state-test] tests are the pure half;
  [`AnsiblePipelineQueue`][queue-test] is the wiring half. (This is the "[Split
  GenServer API from implementation](#general-conventions)" rule, applied.)
- **Start the unit with `start_supervised!/1` under a per-test-scoped name.**
  Derive the registered name from a value passed at init so each test starts its
  own instance, isolated from the application's live process and from other
  tests — the pipeline modules register as `{:global, {Module, pipeline}}`, so a
  unique value per test suffices. Use the **ExUnit context's `:test` key** as
  that value (`setup %{test: test}`): it is a unique atom per test, so it needs
  no runtime atom creation (`String.to_atom`, which Credo rejects) and never
  clashes. `start_supervised!/1` also tears the process down before the next
  test, so a global registration never leaks.
- **Give a spawned process the test's sandbox connection and mocks.** A
  supervised process is a different pid than the test, so it does not
  automatically share either:
  - **Database.** For a process that reads the database _lazily_ (in a
    `handle_*` after start), `start_supervised!/1` then
    `Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)`. For a process that
    reads in `init/1` — which runs _before_ `start_supervised!/1` returns the
    pid, too early to allow — use shared-mode sandbox instead (`async: false`,
    which [`DataCase`][data-case] enables for non-async cases), as
    [`AnsiblePipelineQueue`][queue-test] does.
  - **Injected mocks.** A mock called from _inside_ the process needs
    `Hammox.allow(Mock, self(), pid)` (the `ServerManager` tests allow
    `Ansible.Mock`/`Http.Mock` onto the manager). But a **singleton started at
    application boot is owned by no test**, so its always-running paths must not
    call an injected mock
    ([`Clock`](#deterministic-time-via-an-injectable-clock) or
    [`PubSub.Scope`](#asserting-pubsub-broadcasts)) at all — push the time into
    a pure helper that takes `now` (pinned exactly in the pure tests) and have
    the live process pass wall-clock; the process test then asserts only the
    non-time wiring.
- **Inject a collaborator when a config-resolved mock cannot stand in.** The
  default for a boundary is still a behaviour resolved through
  `Application.compile_env!` and swapped to a Hammox mock in test (`Clock`,
  `Http`, `Cmd`, `Servers.SSH.Client` — the Erlang `:ssh`/`SSHEx` boundary the
  [`ServerConnection`][server-connection-test] process calls lazily, allowed
  onto the process like the others — and the contexts). But that mock is
  **owner-scoped**, so it cannot cover a call made in `init/1` (which runs
  before the test holds the pid) or by a boot-started singleton (owned by no
  test) — the same wall the `Clock` hits. When a process needs such a
  collaborator (e.g. the database work `AnsiblePipelineQueue` does in `init`),
  **pass the collaborator module on `start_link`** instead: the real
  implementation by default, a plain fake in the test. The live process keeps
  the real one; the test's `init` does no real work, so it can run `async: true`
  and can assert the behaviour _through_ the process. Keep the contract honest
  with a **behaviour** — `@behaviour` on the real impl is the compile-time
  check, and `Hammox.protect/2` of the real impl in its own test is the runtime
  one. The injected double stays a **plain module** (a Hammox mock would
  reintroduce the owner problem); verify its calls by having it `send` to a pid
  passed in. Note the injection-site type can only be `module()` — Elixir cannot
  type "a module implementing behaviour B", so the behaviour, not the typespec,
  carries the contract.
- **Drive the process, then read it back — never `Process.sleep`.** Drive
  through the client API or `send/2`, and observe with a **synchronous call**: a
  `call` issued after a `cast` is handled in mailbox order, so it flushes the
  cast with no sleep (the `server_offline` cast then `health` call in
  [`AnsiblePipelineQueue`][queue-test]). For results delivered _as_ messages,
  have the mock `send` to the test and `assert_receive`/`refute_receive`. For
  state convergence not observable through a call, use
  `ProcessTestHelpers.wait_for_state!/wait_for!`, which poll with a timeout.
- **Stand in for a collaborator process** with
  [`GenServerProxy`][gen-server-proxy] — it forwards every call/cast/message to
  the test as `{:proxy, name, …}`, which you match with `assert_receive` and
  answer with `GenServer.reply/2` — and `NoOpGenServer` for a do-nothing process
  to monitor or link. The [`ServerManager`][server-manager-test] tests use both.

## Testing external-tool compatibility

Every test above mocks the external-tool boundary — the `Cmd` (`ExCmd` →
`ansible`/`ansible-playbook`), `Servers.SSH.Client` (`:ssh`/`SSHEx`) and
`Servers.Ansible` façades all resolve to a Hammox mock in the test env. That is
correct for unit coverage, but it means **nothing certifies that the real tools
still speak the format the app parses**: a version bump of OTP `:ssh`, `SSHEx`
or Ansible can break production while every mock stays green. A small set of
compatibility smoke tests closes that gap. They are a **canary for tool drift,
not another coverage sweep** — keep each to one round-trip per contract and
leave ordinary branch logic to the mocked unit tests. The contracts worth
pinning against the real tool are the happy-path output _and_ any **exact tool
output the app matches on** — e.g. the `:ssh` error strings `ServerConnection`
maps to atoms, which an OTP bump can silently reword. Reproducing a failure (an
unauthorized key, a disjoint key-exchange algorithm) is fair game when it
certifies such a string; do not reproduce failures whose handling carries no
external-format contract.

- **Tag them `:external`, and exclude them from the default run.**
  [`test_helper.exs`][test-helper] calls `ExUnit.start(exclude: [external:
true])`, so a `@moduletag :external` test never runs under `mix test` or the
  `mix coveralls.html` coverage run — it contributes nothing to the coverage
  numerator, and the real tool it exercises can be absent locally. A dedicated
  CI job opts in with `mix test --only external`. This keeps the real-tool
  passthrough impls (e.g. [`SystemClient`][system-client]) out of the coverage
  numbers rather than dragging them down as permanently "uncovered".
- **Point the façade at the real tool.** The façades are compile-time bound to
  their mocks in the test env, so a test reprograms the _mock_ to delegate to
  the real implementation, and every call through the façade then hits the real
  subprocess / `:ssh`, exercising the façade indirection itself. Use
  [`Mox.stub_with/2`][mox] when the real implementation module declares the
  façade behaviour — `stub_with(Servers.SSH.Client.Mock,
Servers.SSH.Client.SystemClient)` — even though the mocks are Hammox-defined (it
  maps each behaviour callback to the same-named function in the target). When
  the real tool is a **foreign module that does not declare the behaviour**
  (e.g. `ExCmd` behind `Cmd`), `stub_with/2` raises "do not share any
  behaviour"; stub the callback directly instead — `stub(Cmd.Mock, :stream,
  &ExCmd.stream/2)`.
- **Mind the owner scope.** `stub_with` is owner-scoped like any Mox stub, so
  real work done in a **spawned** GenServer/task (a `ServerConnection`, the
  `Ansible.Runner` task) still needs `allow/3` or global mode — the same wall
  the mocks hit in [runtime-process
  tests](#runtime-processes-genservers-genstage). Driving the façade directly
  from the test process (as the SSH example does) avoids it.
- **Provide the tool; gate on it.** The real tool runs for real, so it must be
  present — these tests are Docker/tool-gated regardless. The SSH round-trip
  stands up an in-process Erlang `:ssh.daemon` ([`SSHDaemon`][ssh-daemon], no
  Docker) and drives the real `Client` against it. The Ansible round-trip needs
  a real host — and the setup playbook also drives `ansible.builtin.systemd`,
  which needs a live systemd/dbus — so
  [`UbuntuServerContainer`][ubuntu-server-container] builds and runs the
  [`ubuntu-server`][ubuntu-server-dockerfile] image (Ubuntu noble booting
  systemd with `python3`, matching the student-VM fleet, authorizing the
  `test/priv/ssh` fixture key) as a privileged container via Testcontainers and
  returns its mapped address.
- **Pin the tool version in one source of truth, and run the test against it.**
  A compatibility test that runs a different tool than production ships proves
  nothing about production. Ansible is pinned in
  [`requirements.txt`][ansible-requirements] (`ansible-core`) and
  [`requirements.yml`][ansible-galaxy-requirements] (`ansible.posix`, which owns
  the JSON/JSONL callbacks and floats independently of `ansible-core`). Both the
  production image (the `Dockerfile`'s Alpine `app` stage) and the CI job
  install from those same files — CI before running the smoke test — so the test
  certifies the version production ships. Treat a bump to either as a reviewed
  change the smoke test gates.
- **Own the pinned output in one module, shared with production.** When the
  compatibility test pins an exact tool output that production also matches on,
  give it a small module that owns the value so three places stay in lockstep:
  the production match, the compatibility test that certifies the _real_ output,
  and the mocked unit test that exercises the mapping. Expose both a
  **constructor** (so the mock can return the exact value) and a **classifier**
  (so production maps it), then unit-test the classifier against the
  constructor's value — the mapping is proven without repeating the literal.
  When the tool drifts, the compatibility test fails, you update the one module,
  and everything else follows. [`ConnectError`][connect-error] does this for the
  two `:ssh` connection-error strings: `authentication_failed/0` /
  `key_exchange_failed/0` build the tuples and `classify/1` maps a reason to its
  atom.

The exemplar is
[`SystemClientCompatibilityTest`][system-client-compatibility-test]: it
`stub_with`s the real `SystemClient` and drives the real `Client` façade against
an [`SSHDaemon`][ssh-daemon] — a happy-path connect / `echo` round-trip /
disconnect against an authorized fixture key, plus an authentication failure
(unauthorized key) and a key-exchange failure (disjoint algorithms), each
asserting the whole error tuple equals `ConnectError.authentication_failed/0` /
`key_exchange_failed/0` (pinning the real `:ssh` string). A fourth case
certifies the security-relevant behaviour rather than a string: with
`silently_accept_hosts: false` (production's default), real `:ssh` rejects an
unknown host key, and the reason classifies as `:other` — the app does not
branch on that string, so it is deliberately not pinned. The mocked
[`ServerConnection`][server-connection-test] tests return the auth/kex tuples to
check the `classify/1` mapping fires end to end, and
[`ConnectErrorTest`][connect-error-test] pins `classify/1` against each
constructor's reason.

The Ansible analogue is [`RunnerCompatibilityTest`][runner-compatibility-test]:
it `stub`s `Cmd.Mock` to real `ExCmd` and drives `Runner` directly against an
[`UbuntuServerContainer`][ubuntu-server-container]. One round-trip per contract
— `gather_facts/3` mapped through
`ServerProperties.update_from_ansible_facts/2`, and `run_playbook/5` over a
trivial [fixture playbook][ansible-compat-playbook] whose real JSONL decodes
through `AnsiblePlaybookEvent.new/3`, then `AnsiblePlaybookRun.update_stats/2`
applied to a persisted run with its exact counts asserted. Both round-trips bind
the non-deterministic real values (host hardware, generated ids, real
timestamps, the raw blobs), validate their shape, and fold them back into a
**whole-value `==`** — a human-approved exception the test comments call out so
it is not read as license for partial assertions. Keep the target generic and
the playbook trivial: the canary certifies the callback format, not the app's
business logic, which the mocked pipeline tests cover.

[contributing]: ../CONTRIBUTING.md#testing
[data-case]: ../test/support/data_case.ex
[telemetry]: ../test/support/telemetry_test_helpers.ex
[pub-sub-scope]: ../lib/archidep/pub_sub/scope.ex
[pub-sub-test-helpers]: ../test/support/pub_sub_test_helpers.ex
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
[gen-server-proxy]: ../test/support/gen_server_proxy.ex
[server-manager-test]: ../test/archidep/servers/server_tracking/server_manager_test.exs
[server-connection-test]: ../test/archidep/servers/server_tracking/server_connection_test.exs
[test-helper]: ../test/test_helper.exs
[system-client]: ../lib/archidep/servers/ssh/client/system_client.ex
[ssh-daemon]: ../test/support/ssh_daemon.ex
[system-client-compatibility-test]: ../test/archidep/servers/ssh/client/system_client_compatibility_test.exs
[connect-error]: ../lib/archidep/servers/ssh/connect_error.ex
[connect-error-test]: ../test/archidep/servers/ssh/connect_error_test.exs
[runner-compatibility-test]: ../test/archidep/servers/ansible/runner_compatibility_test.exs
[ubuntu-server-container]: ../test/support/ubuntu_server_container.ex
[ubuntu-server-dockerfile]: ../test/docker/ubuntu-server/Dockerfile
[ansible-compat-playbook]: ../test/priv/ansible/compat.yml
[ansible-requirements]: ../../requirements.txt
[ansible-galaxy-requirements]: ../../requirements.yml
[queue-state-test]: ../test/archidep/servers/ansible/pipeline/ansible_pipeline_queue_state_test.exs
[queue-test]: ../test/archidep/servers/ansible/pipeline/ansible_pipeline_queue_test.exs
[channel-case]: ../test/support/channel_case.ex
[user-socket-test]: ../test/archidep_web/channels/user_socket_test.exs
[user-channel-test]: ../test/archidep_web/channels/user_channel_test.exs
[auth-controller-test]: ../test/archidep_web/auth/auth_controller_test.exs
[html-test-helpers]: ../test/support/html_test_helpers.ex
[profile-live-test]: ../test/archidep_web/profile/profile_live_test.exs
[current-sessions-live-test]: ../test/archidep_web/profile/current_sessions_live_test.exs
[auth-helpers-test]: ../test/archidep_web/helpers/auth_helpers_test.exs
[core-components-test]: ../test/archidep_web/components/core_components_test.exs
[date-format-helpers-test]: ../test/archidep_web/helpers/date_format_helpers_test.exs
[live-view-helpers-test]: ../test/archidep_web/helpers/live_view_helpers_test.exs
[conn-helpers-test]: ../test/archidep_web/helpers/conn_helpers_test.exs
[dialog-helpers-test]: ../test/archidep_web/helpers/dialog_helpers_test.exs
[server-components-test]: ../test/archidep_web/servers/server_components_test.exs
[events-components-test]: ../test/archidep_web/admin/events/events_components_test.exs
[lazy-html]: https://hexdocs.pm/lazy_html
