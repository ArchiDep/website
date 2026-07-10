# DDD boundary-hardening

The ArchiDep dashboard application (`app/lib/archidep`) already embraces the
**strategic** side of domain-driven design deliberately and rigorously: real
bounded contexts, explicit context mapping, ubiquitous language, domain events.
This isn't documentation aspiring to DDD while the code does something else —
the structure on disk matches the claims. The full assessment that backs this
conclusion is preserved at the [bottom of this
document](#assessment-background).

This top section turns that assessment's improvement suggestions into a
concrete, reviewable backlog. The goal is **not** dogmatic, full-tactical DDD;
it is to close the handful of places where the context boundaries the app
already has can drift or break silently.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [How to use this backlog](#how-to-use-this-backlog)
- [Backlog](#backlog)
  - [A. Boundary contract hardening](#a-boundary-contract-hardening)
  - [B. Restore single ownership of `user_accounts`](#b-restore-single-ownership-of-user_accounts)
  - [C. Remove the context metaprogramming](#c-remove-the-context-metaprogramming)
  - [D. Documentation honesty](#d-documentation-honesty)
  - [E. Cross-context `refresh!` coupling](#e-cross-context-refresh-coupling)
- [Decisions settled](#decisions-settled)
- [Sequencing with the testing plan](#sequencing-with-the-testing-plan)
- [Task details](#task-details)
  - [#1 Read-view contract test](#1-read-view-contract-test)
  - [#1b Provenance comments](#1b-provenance-comments)
  - [#2 Move the server counters into a Servers-owned table](#2-move-the-server-counters-into-a-servers-owned-table)
  - [#2b Update the ownership diagram](#2b-update-the-ownership-diagram)
  - [#3 Hand-write the behaviour/boundary/impl trio](#3-hand-write-the-behaviourboundaryimpl-trio)
  - [#3b Drift-guard test](#3b-drift-guard-test)
  - [#3c Delete the machinery](#3c-delete-the-machinery)
  - [#4 Rename "event sourcing" to "domain event log"](#4-rename-event-sourcing-to-domain-event-log)
  - [#5 Cross-context `refresh!` coupling](#5-cross-context-refresh-coupling)
  - [#5a `refresh!` round-trip consistency tests](#5a-refresh-round-trip-consistency-tests)
  - [#5b Extract the version skeleton](#5b-extract-the-version-skeleton)
  - [#5c Broadcast the domain events as the published payload](#5c-broadcast-the-domain-events-as-the-published-payload)
- [What not to change](#what-not-to-change)
- [Assessment (background)](#assessment-background)
  - [Does it follow DDD?](#does-it-follow-ddd)
  - [Recommended improvements (original analysis)](#recommended-improvements-original-analysis)

<!-- END doctoc -->

---

## How to use this backlog

Each task below is a **reviewable chunk** scoped so a single PR can be read
end-to-end. Pick the next unchecked task, implement it, and check the checkbox
(`- [ ]` → `- [x]`) as part of the same change (per the repository
[`AGENTS.md`](../AGENTS.md) checkbox rule). A human reviews afterwards.

Suggested ordering follows the groups: **A (contract test) → C (de-macro) →
B (move counters) → D (doc rename)**. Group A is the highest-value, lowest-risk
work — it directly closes the one place boundaries can break silently. Groups B
and C are real code changes; D is a pure documentation fix and can be done at any
time.

---

## Backlog

### A. Boundary contract hardening

The highest-value work — the original assessment's "if only one thing." It makes
the "read view" abstraction trustworthy rather than aspirational.

- [x] **#1 Read-view contract test.** One `DataCase` test that iterates over
      every read-view and shared-kernel schema and asserts each mapped source
      column still exists on the live physical table (DB introspection), so a
      migration in the owning context that renames or drops a column fails
      loudly in CI. Cover all eight schemas across both coupling directions —
      see [#1 Read-view contract test](#1-read-view-contract-test).
- [x] **#1b Provenance comments.** Add a one-line comment to each read-view
      schema pointing at the owning context, so the coupling is discoverable
      from the dependent side — see [#1b Provenance
      comments](#1b-provenance-comments).

### B. Restore single ownership of `user_accounts`

The `user_accounts` table is co-owned today: Accounts owns identity/auth, but
the server-count counters on it are written exclusively by Servers. We restore
single ownership by moving those counters out.

- [ ] **#2 Move the server counters into a Servers-owned table.** Migrate
      `active_server_count`, `server_count`, and their `_lock` companions (plus
      the non-negative / lock-positive constraints) off `user_accounts` into a
      new Servers-owned table keyed by `user_account_id`, backfilling existing
      values — see [#2 Move the server counters into a Servers-owned
      table](#2-move-the-server-counters-into-a-servers-owned-table).
- [ ] **#2b Update the ownership diagram.** Reflect the move in
      `app/CONTRIBUTING.md` so `user_accounts` is cleanly Accounts-owned again —
      see [#2b Update the ownership diagram](#2b-update-the-ownership-diagram).

### C. Remove the context metaprogramming

The `callback` / `delegate` / `implement` macros keep the behaviour, public API
and implementation from repeating their docs/specs — but at the cost of heavy
metaprogramming that hides code from Dialyzer, ExDoc and "go to definition." We
replace the macros with plain Elixir and restore the anti-drift guarantee with a
test.

- [ ] **#3 Hand-write the behaviour/boundary/impl trio.** Replace the macros
      with plain `@doc`/`@callback`/`@spec`/`defdelegate` across all four
      contexts — see [#3 Hand-write the behaviour/boundary/impl
      trio](#3-hand-write-the-behaviourboundaryimpl-trio).
- [ ] **#3b Drift-guard test.** One generic ExUnit test over every triple
      (`{boundary, behaviour, impl}`) asserting docs and specs do not drift —
      see [#3b Drift-guard test](#3b-drift-guard-test).
- [ ] **#3c Delete the machinery.** Remove `context_helpers.ex` and its imports
      from `app/lib/archidep.ex` — see [#3c Delete the
      machinery](#3c-delete-the-machinery).

### D. Documentation honesty

- [ ] **#4 Rename "event sourcing" to "domain event log" / "audit log."** Reword
      the Events-context prose; the implementation is good as-is and is
      untouched — see [#4 Rename "event sourcing" to "domain event
      log"](#4-rename-event-sourcing-to-domain-event-log).

### E. Cross-context `refresh!` coupling

The dynamic, in-memory twin of #1. Read-view schemas keep cached structs current
by hand-rolling a `refresh!/2` that pattern-matches the _producer context's raw
struct_, broadcast over PubSub — so the boundary can break or go stale
_silently_. Nine schemas hand-roll the same skeleton with no shared abstraction
and no tests. See [#5 Cross-context refresh!
coupling](#5-cross-context-refresh-coupling) for the full analysis.

- [ ] **#5a `refresh!` round-trip consistency tests (loud-failure guard).** A
      `DataCase` test per consumer that bumps the producer to N+1 and asserts
      `Consumer.refresh!(old, producer_struct)` equals a fresh DB fetch — with
      the DB row and the broadcast struct deliberately diverged so the test
      proves the in-memory merge path ran, not the masking re-fetch fallback.
      Highest priority: the loud guard and the safety net for #5b/#5c — see [#5a
      refresh! round-trip consistency
      tests](#5a-refresh-round-trip-consistency-tests).
- [ ] **#5b Extract the version skeleton into a plain helper.** Pull the
      identical `version <= current` no-op and gap-refetch fallback clauses out
      of all nine schemas into a plain (non-macro) higher-order function,
      leaving only the per-schema field mapping — see [#5b Extract the version
      skeleton](#5b-extract-the-version-skeleton).
- [ ] **#5c Broadcast the domain events as the published payload.** Broadcast
      the existing `*Updated` domain events as the cross-context contract
      instead of the raw aggregate, so consumers match a named, producer-owned
      shape — see [#5c Broadcast the domain events as the published
      payload](#5c-broadcast-the-domain-events-as-the-published-payload).

---

## Decisions settled

These choices were made deliberately; they are recorded here so the backlog
items stay short.

- **#1 scope.** The contract test covers **all** read-view and shared schemas
  (eight), in both coupling directions — not just the two (`ServerOwner`,
  `Course.User`) the original prose named. The coupling is symmetric: Accounts
  also reads Course-owned tables, and Servers reads both.
- **#2 resolution.** **Move the counters out** into a Servers-owned table
  (cleaner boundary), rather than "accept and document the split ownership."
  This accepts an extra join and the loss of the in-place optimistic-lock
  counter on `user_accounts` as the cost of restoring single ownership.
- **#3 direction.** **Remove the macros** and restore the anti-drift guarantee
  with an ExUnit drift test — not a compile-time hook, and not the status quo.
  Rationale: the macros' whole purpose is preventing doc/spec drift across the
  three modules; a test reproduces that guarantee in CI while keeping the
  modules as plain, tooling-legible Elixir (go-to-spec, Dialyzer, ExDoc and "go
  to definition" all work). The cleverness is confined to one test module rather
  than spread across every context. A compile-time `@after_verify` hook was
  considered and rejected because it reintroduces a sliver of macro/magic into
  the production modules, partially undercutting the reason to remove the
  macros.
- **#3 doc home.** `@doc` is **duplicated on both the behaviour and the
  boundary**, and the drift test enforces a byte-for-byte match — matching the
  original intent that all the modules carry the same `@doc`. The implementation
  module keeps `@doc false`, as it does today.
- **#5 sequencing.** Fix all three facets (shape coupling, silent failure,
  boilerplate/no-tests) eventually, in a firm order: **#5a round-trip tests
  first** (the loud guard and the safety net that makes the later refactors
  safe), then **#5b** the plain-function skeleton extraction, then **#5c** the
  published-payload anti-corruption layer. The #5b helper is a plain function,
  **never a macro** — consistent with the #3 de-macro decision.
- **#5c published payload.** **Reuse the existing domain events** as the
  cross-context contract rather than declaring a new shape — they are already
  named, implement the `Event` protocol, and (being persisted as immutable JSON)
  are forced to stay backward-compatible, exactly the stability a published
  contract needs. Handle the field gaps by three buckets: carry `version` /
  `updated_at` on the broadcast envelope (not in the event data); **prune**
  secrets / volatile operational fields (`secret_key`, `last_known_properties`,
  …) rather than persisting them in the audit log; and **enrich** only
  genuinely-shared fields (e.g. add `expected_server_properties` to
  `ClassUpdated`). Keep events curated, not full-row snapshots, so #4 ("event
  log, not event sourcing") stays honest — using events as cache-refresh
  notifications is not event sourcing. **Open, to decide at implementation
  time:** whether to convert only the cross-context refreshers or all of them
  (intra-context refresh crosses no boundary, so broadcasting the aggregate
  there is defensible).

---

## Sequencing with the testing plan

This plan is independent of [`death-of-jekyll.md`](./death-of-jekyll.md) but
**interleaved with** the now-complete testing plan (its conventions live in
[`app/docs/testing.md`](../app/docs/testing.md)): some coverage work touches code
these refactorings reshape. The goal is to harden the
test foundation first _without_ writing tests the DDD work will throw away.

The refactorings split in two, and the split is what makes interleaving safe:

- **Behavior-preserving (test-transparent):** #3 (de-macro — the public API and
  the Hammox mocks are unchanged) and #5b (extract the version skeleton — a pure
  internal refactor). Tests written before these survive them untouched, despite
  the large file footprint.
- **Contract-changing (the only real test-invalidators):** #2 (server-count
  storage moves tables) and #5c (broadcasts change from the raw aggregate to a
  domain event).

One ordering is fixed: **#5a must precede #5c** — the round-trip tests are the
safety net that makes the broadcast change safe, so for `refresh!` the order is
test → refactor → _adjust_ the test, not "test everything last."

**The lever is writing black-box behavioral tests.** A test that asserts
observable behavior ("creating the N+1th server returns a limit-reached error")
rather than internal structure ("`user_accounts` has an `active_server_count`
column") survives almost every refactoring here. That shrinks the volatile
surface to three named slices, each deferred to ship with the DDD task that
finalizes its structure:

- `refresh!` clause structure → ships with #5a–#5c;
- server-count storage / `ServerOwner.update_server_count/2` → ships with #2;
- broadcast-driven live-update assertions in LiveViews/channels → ship with #5c.

Everything else in `testing.md` is DDD-stable and should be written now.

**Recommended order:**

1. `testing.md` §0 Foundations (fixtures, `ChannelCase`, coverage ratchet) —
   pure prerequisite, no overlap.
2. _(Optional, early)_ #3 / #3b / #3c — test-neutral, and deleting
   `context_helpers.ex` raises the coverage baseline while making the contexts
   plain Elixir for everyone about to write tests.
3. `testing.md` §1–§5 black-box sweep of all DDD-stable surfaces; defer only the
   three volatile slices above (still cover the non-broadcast parts of the
   affected LiveViews/channels).
4. #1 / #1b read-view contract test + provenance comments — an additive early
   win that pairs with the deferred refresh tests.
5. #2 / #2b counter move — ships its own counter tests (the deferred slice).
6. #5a → #5b → #5c — safety net, then skeleton, then broadcasts, updating #5a's
   inputs and the deferred PubSub-driven tests as part of #5c.
7. #4 doc rename — anytime.
8. `testing.md` §6 finalize coverage policy — last, once the real coverage map
   is visible (exactly where `testing.md` already puts it).

The two plans are **synergistic on coverage**, not antagonistic: #3c removes
uncovered metaprogramming (the number goes up) and every DDD task adds tests (#1
contract, #3b drift, #5a refresh, #2 counters), so the ratchet only benefits.
One refinement for `testing.md`: its web canon exemplar (`server_live`) sits on
#5c-volatile code — either set that layer's "PubSub-driven updates" convention
_after_ #5c, or pick a DDD-stable exemplar so the agreed pattern isn't
disturbed.

---

## Task details

Detail for the [Backlog](#backlog). Each subsection fleshes out one checkbox.

### #1 Read-view contract test

The one real architectural smell the assessment flags: read-view schemas couple
on the _physical table_, not a published contract. For example,
`Servers.Schemas.ServerOwner` does `schema "user_accounts"` and hardcodes
Accounts' column names. If the owning context renames a column or restructures
the table, the dependent context breaks — and nothing in the type system or
compiler warns; it fails at runtime against the DB.

Add a single `DataCase` test that introspects the live database and, for each
read-view / shared schema, asserts every mapped source column still exists on
the underlying physical table. (Query the actual columns via the repo /
`information_schema` so a migration in the owning context is caught regardless
of whether the owning Ecto schema was updated.) Iterate over all eight schemas:

- read `user_accounts` (owned by Accounts):
  `ArchiDep.Servers.Schemas.ServerOwner`, `ArchiDep.Course.Schemas.User`
- read `classes` (owned by Course): `ArchiDep.Accounts.Schemas.UserGroup`,
  `ArchiDep.Servers.Schemas.ServerGroup`
- read `students` (owned by Course):
  `ArchiDep.Accounts.Schemas.PreregisteredUser`,
  `ArchiDep.Servers.Schemas.ServerGroupMember`
- shared `server_properties`:
  `ArchiDep.Course.Schemas.ExpectedServerProperties`,
  `ArchiDep.Servers.Schemas.ServerProperties`

Keep the list of `{schema, table}` pairs in one place in the test so adding a
new read-view schema is a one-line addition. This aligns with the testing
conventions in [`app/docs/testing.md`](../app/docs/testing.md). The same boundary
has an in-memory twin — see
[#5 Cross-context refresh! coupling](#5-cross-context-refresh-coupling), where
read-views couple on the producer's _broadcast struct shape_ rather than its
table.

### #1b Provenance comments

Add a one-line comment at the top of each read-view schema (the six
cross-context ones above) naming the owning context and table, so the coupling
is discoverable from the dependent side — e.g. a reader of `ServerOwner`
immediately sees it is a read view over the Accounts-owned `user_accounts`
table. Cheap, and it pairs with the contract test by making the dependency
explicit in source as well as in CI.

### #2 Move the server counters into a Servers-owned table

The counter columns (`active_server_count`, `server_count`, and their
`active_server_count_lock` / `server_count_lock` companions) live on
`user_accounts` but are written **exclusively** by Servers, never by Accounts.
So `user_accounts` is really co-owned. Move the counters out to restore single
ownership.

What exists today (for reference, not edited by this doc):

- **Migrations** that added the columns:
  `app/priv/repo/migrations/20250708120510_add_active_server_count_to_user_accounts.exs`
  and `…20250922201547_add_server_count_to_user_accounts.exs` (with the
  `>= 0` and `_lock >= 1` check constraints).
- **Schema**: `app/lib/archidep/servers/schemas/server_owner.ex` maps the four
  fields and defines `update_server_count/2`, `update_active_server_count/2`
  (both using `optimistic_lock/2`) plus `active_server_limit_reached?/1`,
  `server_limit_reached?/1`. The Accounts-owned `UserAccount` schema does **not**
  map these fields.
- **Writers**: `servers/use_cases/{create_server,delete_server,update_server}.ex`
  increment/decrement the counters inside their `Ecto.Multi`.
- **Readers**: only the limit checks above and the validation error messages in
  `servers/schemas/server.ex`. No UI displays these counters.
- **Key**: `servers.user_account_id` already FKs `user_accounts`
  (`…20250608181323_add_servers.exs`).

The move:

- New Servers-owned table (e.g. `server_owner_counters`) keyed by
  `user_account_id` (binary_id, FK to `user_accounts`), carrying the four
  columns and their constraints. Backfill existing values in the migration.
- Rework `ServerOwner` (and/or a dedicated counters schema) so the counters load
  and the optimistic-lock counter still works against the new table; update the
  three writer use cases accordingly.
- Cover the new table with the read-view contract test (#1) if any context reads
  it across a boundary, and update the servers factory.

This trades a join and loses the cheap in-place counter, which is the accepted
cost of single ownership (see [Decisions settled](#decisions-settled)).

### #2b Update the ownership diagram

Once the counters move, update the mermaid ownership diagram and surrounding
prose in `app/CONTRIBUTING.md` (around lines 404–440) so `user_accounts` is
shown as cleanly Accounts-owned (read-only edges from Course and Servers) and
the new counters table appears as Servers-owned. This removes the slight
idealization the assessment notes, where the diagram showed `user_accounts` as
Accounts-owned even though Servers writes a slice of it.

### #3 Hand-write the behaviour/boundary/impl trio

Replace the `callback` / `delegate` / `implement` macros
(`app/lib/archidep/helpers/context_helpers.ex`) with plain Elixir across all
four contexts (Accounts, Course, Events, Servers — ~54 functions). The trio
exemplar is `app/lib/archidep/accounts.ex` (boundary),
`app/lib/archidep/accounts/behaviour.ex` (behaviour) and
`app/lib/archidep/accounts/context.ex` (impl). Per function:

- **Behaviour**: hand-written `@doc` + `@callback`.
- **Boundary**: hand-written `@doc` (duplicated from the behaviour) + `@spec` +
  `defdelegate … to: @implementation`.
- **Implementation**: `@impl Behaviour` + `defdelegate … to: UseCases.X` — no
  `@doc`/`@spec` (it keeps `@doc false` and leans on `@impl`), exactly as today.

Keep the auto-aliases the hand-written specs rely on (`Authentication`,
`Changeset`, `UUID`, and `EventReference` in behaviours — currently injected by
`use ArchiDep, :context*` in `app/lib/archidep.ex`), or alias them explicitly in
each module, so specs like `Authentication.t()` still resolve.

### #3b Drift-guard test

One generic ExUnit test over every `{boundary, behaviour, impl}` triple (driven
by a list of the four context triples). For each behaviour callback, assert:

- the **boundary** and **impl** both export a function of the same name/arity;
- the boundary `@doc` matches the behaviour `@doc` **byte-for-byte**
  (`Code.fetch_docs/1`);
- the boundary `@spec` matches the `@callback` after **normalization**
  (`Code.Typespec.fetch_specs/1` vs `Code.Typespec.fetch_callbacks/1`): zero out
  line metadata and strip the `arg :: T` name annotations so `fun(data :: T,
meta :: map)` compares equal to `fun(T, map)`. The robust route is to render
  both through `Code.Typespec.spec_to_quoted/2` → `Macro.to_string/1` after
  dropping the annotations and compare the strings.

This is the only place the removed macros' guarantee is reconstructed; it lives
entirely in `test/` and runs in CI. The sole fiddly part is the spec
normalization (~30–40 lines, written once).

### #3c Delete the machinery

Remove `app/lib/archidep/helpers/context_helpers.ex` and the `ContextHelpers`
imports from the three `use ArchiDep, :context*` clauses in
`app/lib/archidep.ex` (lines 15–43), keeping the alias injections that the
hand-written specs depend on. Confirm Hammox mocks (generated from the behaviour
modules in `test/support/mocks.ex`) still compile and pass — the behaviours
still emit standard `@callback`, so nothing about contract-checking changes.

### #4 Rename "event sourcing" to "domain event log"

The Events context stores immutable domain events in the same `Ecto.Multi` as
each state change — excellent, and the consistency guarantee is the right call.
But it is an **append-only domain event / audit log**, not event sourcing: state
is still the source of truth in its own tables, and events are never replayed to
reconstruct state. Calling it "event sourcing" sets an expectation (projections,
rebuild-from-events) the code does not meet.

Reword the prose to "domain event log" / "audit log" in:

- `app/CONTRIBUTING.md` (lines 378 and 494 — the `Events` context summary and
  the "implements **event sourcing** for auditing" paragraph);
- `app/lib/archidep/events.ex` (the module doc, line 3).

Pure documentation fix; the implementation is good as-is and is not touched.

### #5 Cross-context `refresh!` coupling

Each aggregate and read-view schema hand-rolls a `refresh!/2` that keeps a
cached struct current in response to a PubSub broadcast, with the same
three-clause skeleton:

1. **`version == current + 1`** → merge the incoming struct's fields into the
   cached struct _in memory_ (recursing into nested associations);
2. **`version <= current`** → no-op (stale/duplicate broadcast);
3. **catch-all `(%{id}, %{id})`** → re-fetch the whole struct from the DB via
   `fetch_*`.

It is, in effect, a hand-rolled per-schema _incremental projection_: apply
version N+1 to in-memory state, fall back to a full read on a gap. Three
problems, all in the DDD-boundary theme:

- **Shape coupling — the in-memory twin of #1.** Every context broadcasts its
  **raw internal aggregate** (`{:class_updated, %Class{}, _}`); the consuming
  read-view then pattern-matches the _producer's field names_
  (`Servers.ServerGroup.refresh!` matches `Class`'s `teacher_ssh_public_keys`;
  `Course.User.refresh!` matches Accounts' `preregistered_user` and Servers'
  `group_member`). Undocumented, bidirectional, with no compile-time guard — the
  same smell as #1 but at the broadcast-struct layer.
- **Silent failure.** When a producer renames a field, the `+1` clause simply
  stops matching and execution falls through to the catch-all DB re-fetch.
  Correctness is preserved (the DB has the new data), so nothing crashes and no
  test fails — the in-memory optimization just dies silently and every update
  degrades to a cross-context DB read. Likewise, forgetting a field in the `+1`
  merge body serves _stale_ data in the UI until a version-gap re-fetch happens
  to fire. Both fail invisibly.
- **Boilerplate, no abstraction, no tests.** Nine schemas re-implement the
  skeleton and re-list every field, with no shared helper and zero `refresh!`
  test coverage.

The fix proceeds in three tasks (#5a → #5b → #5c). This is the dynamic
counterpart to #1's "make the boundary fail loudly in CI."

### #5a `refresh!` round-trip consistency tests

The loud-failure guard, and the safety net that makes #5b and #5c safe to do.
For each read-view consumer that refreshes from a producer struct (`Course.User`
← `PreregisteredUser` / `ServerGroupMember`; `Servers.ServerOwner` ← `Student`;
`Servers.ServerGroup` ← `Class`; `Servers.ServerGroupMember` ← `Student`) — plus
the same-type refreshers (`Server`, `Class`, `Student`, `ServerGroup`) — add a
`DataCase` test that:

- inserts producer + consumer, bumps the producer to version N+1, then
- asserts `Consumer.refresh!(old_consumer, producer_struct)` equals a fresh DB
  fetch of the consumer.

Crucially, **make the DB row and the broadcast struct diverge** (e.g. write one
value to the DB but hand `refresh!` a struct carrying a different value), then
assert the result reflects the _broadcast_ value. This proves the in-memory
merge path ran rather than the catch-all re-fetch — otherwise the fallback
silently returns the DB value and the test passes even though the coupling is
broken. A renamed or forgotten field then fails _loudly_ in CI. Add unit tests
for the `<=` no-op and gap-refetch clauses too. Aligns with the [testing
conventions](../app/docs/testing.md), which deferred `refresh!` coverage to land
here.

### #5b Extract the version skeleton

The `version <= current` no-op clause and the catch-all re-fetch fallback are
identical across all nine schemas. Pull them into a **plain higher-order
function** (current struct + incoming-with-version + a `fetch` function + a
field-mapper function), leaving only the per-schema field mapping at each call
site. It must be a plain function, **not a macro** — consistent with the #3
decision to remove metaprogramming. This is a DRY/readability win; the actual
silent-staleness guard is #5a, which must land first.

### #5c Broadcast the domain events as the published payload

The anti-corruption fix. Instead of broadcasting the raw internal aggregate, the
producing context broadcasts its existing `*Updated` **domain event** (e.g.
`ArchiDep.Course.Events.ClassUpdated`) as the cross-context contract, so a
consumer's `refresh!` matches a declared, named, producer-owned shape rather
than the producer's ORM internals. **Reuse the events**, do not declare a new
shape: they already implement the `Event` protocol
(`app/lib/archidep/events/store/event.ex`), are named in ubiquitous language,
and — because they are persisted as immutable JSON — are already forced to stay
backward-compatible, which is exactly the stability a published contract needs.

The events are _curated_ snapshots, so they omit some fields `refresh!` merges
today; reconcile the gaps by three buckets:

- **`version` / `updated_at` → carry on the broadcast envelope**, not inside the
  event data. `version` already lives on the `StoredEvent` wrapper
  (`app/lib/archidep/events/store/stored_event.ex`), and the PubSub message
  already passes the event reference alongside the payload; `refresh!`'s version
  arithmetic reads it from the envelope.
- **secrets / volatile operational fields → prune, never enrich.** `secret_key`,
  `last_known_properties`, `set_up_at`, etc. must not be added to the immutable
  audit log just to feed `refresh!`. Each is in an _intra-context_ refresh
  anyway, so it is not part of the boundary problem — and a cross-context
  read-view that needed a secret would itself be a red flag.
- **genuinely-shared fields → enrich the event legitimately**, e.g. add
  `expected_server_properties` to `ClassUpdated`, which `ServerGroup` needs and
  which is real shared-kernel data.

Largest change; sequenced last, behind the #5a safety net. Touches the
`pub_sub.ex` modules (`course`, `accounts`, `servers`), the relevant
`*/events/*_updated.ex` structs, and every consumer `refresh!`. This is
consistent with #4: using events as _notification payloads to refresh a cache_
is not event sourcing (state stays in the DB; nothing is rebuilt from the
stream) — provided the events stay curated and are **not** bloated into full-row
state snapshots. Whether to convert only the cross-context refreshers or all of
them (intra-context refresh crosses no boundary) is left to decide when the work
starts.

---

## What not to change

- The **use-case-per-operation** layout (`create_class.ex` et al.) is genuinely
  clean — small, single-purpose, testable, and the `Multi` + event + pubsub
  shape is consistent. The strongest part; leave it.
- The **behaviour-per-context + Hammox** contract-testing setup is the right
  amount of ceremony for mockable boundaries.
- **Authorization-policy-per-context** is well placed.

---

## Assessment (background)

_The analysis below is the original assessment that justified the backlog above.
It is retained for context; the actionable plan is the backlog._

### Does it follow DDD?

Yes — and deliberately so. This isn't documentation aspiring to DDD while the
code does something else; the structure on disk matches the claims.

**Where it clearly applies DDD.** Bounded contexts are real and enforced
structurally. The app is split into `Accounts`, `Course`, `Servers`, and
`Events`, each a self-contained module tree with a consistent anatomy:

- a public API module (`context.ex`) — the only intended entry point
- a `behaviour.ex` defining the contract (also enabling mocking)
- `use_cases/` — one module per operation (`create_class.ex`,
  `delete_student.ex`, `import_students.ex`…), essentially the
  application-service / command-handler layer
- `schemas/` — the Ecto persistence + domain data
- `policy.ex` — context-local authorization rules
- `events/` — domain events
- `types.ex`, `pub_sub.ex`

That's a textbook bounded-context layout, and it's uniform across contexts.

**Context mapping is explicit.** The most convincing DDD signal is how
cross-context data sharing is handled. The same DB table (`user_accounts`) is
owned/written by `Accounts` but exposed to other contexts through _separate
read-view schemas_ — `Servers.ServerOwner`, `Course.User` — each modeling only
what that context cares about. That's the DDD instinct that the same underlying
data is a different model in a different context, rather than one shared "User"
god-object. `server_properties` is a genuine shared kernel (Course writes
_expected_, Servers writes _actual_).

**Domain events / ubiquitous language.** Events are named in domain terms
(`ClassCreated`, `ServerFactsGathered`, `AnsiblePlaybookRunFinished`) and
persisted in the _same_ `Ecto.Multi` as the state change, so state and audit log
stay consistent.

**Honest caveats.**

- **It maps cleanly onto Phoenix contexts.** Much of this is also idiomatic
  Phoenix. The DDD vocabulary fits, but a Phoenix developer would arrive at a
  similar shape without invoking DDD by name.
- **Not full tactical DDD.** No aggregates / value-objects / repositories as
  distinct named building blocks — persistence is plain Ecto schemas, not a
  domain model behind a repository abstraction.
- **It's pragmatic, not dogmatic.** The read-view-schema pattern is a nice
  anti-corruption-ish boundary, but contexts still read each other's tables
  directly rather than only through published APIs.

**Bottom line.** It strongly embraces the **strategic** side of DDD — bounded
contexts, explicit context mapping, ubiquitous language, domain events — and
organizes around them rigorously. It's lighter on **tactical** DDD patterns
(aggregates, repositories, value objects), leaning instead on idiomatic
Phoenix/Ecto.

### Recommended improvements (original analysis)

The architecture is genuinely well-executed, and most of what's flagged below
are trade-offs already made deliberately rather than mistakes. Roughly in
priority order. _(The actionable form of each is in the [Backlog](#backlog)
above.)_

**1. Read-view schemas couple on the _physical table_, not a published
contract.** This is the one real architectural smell.
`Servers.Schemas.ServerOwner` does `schema "user_accounts"` and hardcodes
Accounts' column names (`student_id`, `version`, the timestamp columns…). So the
context boundary that the docs describe as a clean "read view" is, at the
database level, a **direct structural dependency on another context's table
layout**. If Accounts renames a column or restructures `user_accounts`, Servers
breaks — and nothing in the type system or compiler will warn; it'll fail at
runtime against the DB. Two cheap mitigations: a test that asserts each
read-view schema's fields still exist on the owning table, and a one-line
comment in each read-view schema pointing at the owning context. _(→ tasks #1
and #1b.)_

**2. The `user_accounts` table has split ownership — name it.** The counter
columns (`active_server_count`, `server_count`, and their `_lock` companions)
live on `user_accounts` but are written _exclusively_ by Servers
(`ServerOwner.update_server_count/2`), never by Accounts. So `user_accounts` is
really co-owned: Accounts owns identity/auth, Servers owns the server tallies.
The ownership diagram in `app/CONTRIBUTING.md` shows `user_accounts` as
Accounts-owned with only _read_ edges from Servers — but Servers writes those
columns. Two honest options: accept it and document the shared slice, or move
the counters out into a Servers-owned table keyed by user id, restoring single
ownership. _(→ tasks #2 and #2b. **Decision:** move the counters out.)_

**3. The context macros are clever, but they're heavy metaprogramming.**
`ContextHelpers` (`callback`/`delegate`/`implement`) parses AST, expands
aliases, and synthesizes specs/docs to keep the behaviour, the public API, and
the impl from repeating themselves. It works and it's applied consistently — but
it's exactly the "unnecessary macro" / hard-to-trace-indirection trade-off in
the design-anti-patterns doc the project's own guidelines cite. The cost: a
newcomer (or future-you) can't jump from `ArchiDep.Accounts.<fun>` to the spec,
and tooling (Dialyzer, docs, "go to definition") sees generated code. The reason
the macros were introduced is real, though: keeping the three modules'
functions, `@doc` comments and specs/callbacks identical without repetition, and
preventing them from drifting. _(→ tasks #3, #3b, #3c. **Decision:** remove the
macros and reconstruct the anti-drift guarantee with an ExUnit drift test,
duplicating the docs/specs by hand.)_

**4. "Event sourcing" oversells what's actually an audit log.** The `Events`
context stores immutable domain events in the same `Ecto.Multi` as each state
change — excellent, and the consistency guarantee is the right call. But it's an
**append-only event/audit log**, not event sourcing: state is still the source
of truth in its own tables, and events are never replayed to reconstruct state.
Calling it "event sourcing" in the docs sets an expectation (projections,
rebuild-from-events) the code doesn't meet, which can mislead a contributor into
thinking they can/should derive state from the stream. Rename it "domain event
log" / "audit log" in the prose. Pure documentation fix; the implementation is
good as-is. _(→ task #4.)_

**5. Cross-context `refresh!` couples on the producer's struct shape (added in a
later session).** Read-view schemas keep cached structs current by hand-rolling
a `refresh!/2` that pattern-matches the _raw aggregate_ each context broadcasts
over PubSub — the in-memory twin of smell #1, but on the broadcast-struct layer
rather than the table. When a producer renames a field, the in-memory merge
clause stops matching and execution falls through to a catch-all DB re-fetch:
correctness is preserved, so it fails _silently_ (the optimization dies, or a
forgotten field serves stale UI data) with nothing in CI to catch it. Nine
schemas hand-roll the same skeleton with no shared abstraction and no tests. _(→
tasks #5a, #5b, #5c. **Decision:** add loud round-trip tests first, then a
plain-function skeleton helper, then broadcast the existing domain events as the
published contract.)_

**If only one thing.** Do **#1's contract test for the shared tables.** A few
lines, it directly closes the one place where the boundaries can break silently,
and it makes the "read view" abstraction trustworthy rather than aspirational.
Everything else is documentation honesty or a trade-off worth keeping.
