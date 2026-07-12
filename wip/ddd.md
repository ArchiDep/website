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
  - [F. Event schema versioning](#f-event-schema-versioning)
  - [G. Curated read views](#g-curated-read-views)
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
  - [#5d Consolidate subscribe + reconcile behind the context](#5d-consolidate-subscribe--reconcile-behind-the-context)
  - [#5e Sweep the remaining consumers](#5e-sweep-the-remaining-consumers)
  - [#6 Record a `schema_version` per stored event](#6-record-a-schema_version-per-stored-event)
  - [#6b Event-shape drift guard](#6b-event-shape-drift-guard)
  - [#7 Curated read views + broadcast-shape uniformity](#7-curated-read-views--broadcast-shape-uniformity)
  - [#7b Sweep the remaining read models](#7b-sweep-the-remaining-read-models)
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

- [x] **#2 Move the server counters into a Servers-owned table.** Migrate
      `active_server_count`, `server_count`, and their `_lock` companions (plus
      the non-negative / lock-positive constraints) off `user_accounts` into a
      new Servers-owned table keyed by `user_account_id`, backfilling existing
      values — see [#2 Move the server counters into a Servers-owned
      table](#2-move-the-server-counters-into-a-servers-owned-table).
- [x] **#2b Update the ownership diagram.** Reflect the move in
      `app/CONTRIBUTING.md` so `user_accounts` is cleanly Accounts-owned again —
      see [#2b Update the ownership diagram](#2b-update-the-ownership-diagram).

### C. Remove the context metaprogramming

The `callback` / `delegate` / `implement` macros keep the behaviour, public API
and implementation from repeating their docs/specs — but at the cost of heavy
metaprogramming that hides code from Dialyzer, ExDoc and "go to definition." We
replace the macros with plain Elixir and restore the anti-drift guarantee with a
test.

- [x] **#3 Hand-write the behaviour/boundary/impl trio.** Replace the macros
      with plain `@doc`/`@callback`/`@spec`/`defdelegate` across all four
      contexts — see [#3 Hand-write the behaviour/boundary/impl
      trio](#3-hand-write-the-behaviourboundaryimpl-trio).
- [x] **#3b Drift-guard test.** One generic ExUnit test over every triple
      (`{boundary, behaviour, impl}`) asserting docs and specs do not drift —
      see [#3b Drift-guard test](#3b-drift-guard-test).
- [x] **#3c Delete the machinery.** Remove `context_helpers.ex` and its imports
      from `app/lib/archidep.ex` — see [#3c Delete the
      machinery](#3c-delete-the-machinery).

### D. Documentation honesty

- [x] **#4 Rename "event sourcing" to "domain event log" / "audit log."** Reword
      the Events-context prose; the implementation is good as-is and is
      untouched — see [#4 Rename "event sourcing" to "domain event
      log"](#4-rename-event-sourcing-to-domain-event-log).

### E. Cross-context `refresh!` coupling

The dynamic, in-memory twin of #1. Read-view schemas keep cached structs current
by hand-rolling a `refresh!/2` that pattern-matches the _producer context's raw
aggregate struct_, broadcast over PubSub — so the boundary can break or go stale
_silently_. Seven schemas hand-roll the skeleton; a runtime audit found only
**two** live cross-context in-memory merges (both Course → Servers), several
**dead** refreshers, and **zero** tests. See [#5 Cross-context refresh!
coupling](#5-cross-context-refresh-coupling) for the full analysis.

- [x] **#5a `refresh!` round-trip consistency tests (loud-failure guard).** A
      `DataCase` test per _live_ merge (the five that actually fire today; not
      the dead refreshers #5c deletes) that bumps the producer to N+1 and
      asserts `Consumer.refresh!(old, incoming)` equals a fresh DB fetch — with
      the DB row and the broadcast payload deliberately diverged so the test
      proves the in-memory merge path ran, not the masking re-fetch fallback.
      Highest priority: the loud guard and the safety net for #5b/#5c — see [#5a
      refresh! round-trip consistency
      tests](#5a-refresh-round-trip-consistency-tests).
- [x] **#5b Extract the version skeleton into a plain helper.** Pull the
      identical `version <= current` no-op and gap-refetch fallback clauses out
      of the live schemas into a plain (non-macro) higher-order function,
      leaving only the per-schema field mapping — see [#5b Extract the version
      skeleton](#5b-extract-the-version-skeleton).
- **#5c Publish domain events as every `refresh!` payload.** Make each producing
  context broadcast its curated domain event (with `version` / `occurred_at` on
  the `EventReference` envelope) as the payload of every `refresh!`-feeding
  broadcast — intra- and cross-context alike — so consumers match a named,
  producer-owned shape and no topic is a latent cross-context trap. Split into
  three reviewable increments (the shared envelope change lands with the first)
  — see [#5c Broadcast the domain events as the published
  payload](#5c-broadcast-the-domain-events-as-the-published-payload).
  - [x] **#5c-i Envelope + Course `class_updated`.** Enrich `EventReference` /
        `to_reference` with `version` + `occurred_at`; generalize
        `versioned_refresh` to not require a top-level id on the payload;
        broadcast `ClassUpdated` / `ClassExpectedServerPropertiesUpdated` from
        `publish_class_updated`; convert `Course.Class` and `Servers.ServerGroup`
        `refresh!/3` plus every `class_updated` consumer (six web modules +
        `ServerManagerState.group_updated`); delete the dead `ServerGroup` intra
        clause.
  - [x] **#5c-ii Course `student_updated` (+ Accounts linkage).** Thread an
        `EventReference` through `publish_student_updated`; broadcast
        `StudentUpdated` / `StudentConfigured`; convert `Course.Student` (intra)
        and `Servers.ServerGroupMember` (cross); add the curated Accounts
        linkage event closing the `preregistered_user` always-refetch omission;
        delete the dead `Course.User` / `ServerOwner` refreshers and the dead
        `Student` / `ServerGroupMember` clauses.
  - [x] **#5c-iii Servers `server_updated` + tracker events.** Broadcast
        `ServerUpdated` and the three tracker events (`ServerFactsGathered` /
        `ServerSetUp` / `ServerOpenPortsChecked`); convert `Servers.Server`
        `refresh!`; resolve the `last_known_properties` gap by **replacing** the
        raw `facts` blob on `ServerFactsGathered` with the derived
        `ServerProperties` (schema version 2, behind **#6**). Consumers converted
        with the full event-driven approach (Option A): cached read-models call
        `refresh!`, and the two that add a newly-appearing server fetch it.
- [ ] **#5d Consolidate subscribe + reconcile behind the context (exemplar).**
      Give each live read-model a `Context.subscribe_<entity>/1` and
      `Context.refresh_<entity>/2` (`{:ok, entity} | :ignore`, owning the
      event→`refresh!` dispatch), plus a plain `ArchiDepWeb.LiveRefresh` helper
      built on `attach_hook(:handle_info)`, so consumers delegate opaque
      messages and name no events. In-process only — no per-entity process. Land
      the helper + one converted exemplar here; the remaining consumers follow
      in a mechanical sweep (#5e). After #5c — see [#5d Consolidate subscribe +
      reconcile behind the
      context](#5d-consolidate-subscribe--reconcile-behind-the-context).
- [ ] **#5e Sweep the remaining consumers.** Convert the rest of the web
      consumers to the #5d pattern (`subscribe_<entity>` + `LiveRefresh.attach`,
      dropping their per-event `handle_info` clauses) — mechanical once #5d sets
      the exemplar — see [#5e Sweep the remaining
      consumers](#5e-sweep-the-remaining-consumers).

### F. Event schema versioning

The audit log is append-only, so every change to an event's payload shape leaves
older rows in the old shape forever. Track the shape explicitly with a per-row
`schema_version`, so a future reader differentiates versions by a declared tag,
never by sniffing which keys are present (the #1/#5 smell — and lossy: an absent
field can't be told from a recorded-null one). Prerequisite for #5c's
`ServerFactsGathered` enrichment.

- [x] **#6 Record a `schema_version` per stored event.** Add a `schema_version`
      column (backfilled to 1, **no** DB default so a forgotten stamp fails
      loudly) and resolve each event's version (default to 1) at write time in
      `add_to_stream/2` — **without** touching the 35 existing `Event` impls (a
      per-event `event_version/0` read reflectively, or a central type→version
      registry; **not** `@fallback_to_any`, which doesn't fill a missing
      function on existing impls). Bump on **every** shape change, additive
      included. No upcasting yet — record the version, defer transforming old
      payloads until a reader needs it — see [#6 Record a schema_version per
      stored event](#6-record-a-schema_version-per-stored-event).
- [x] **#6b Event-shape drift guard.** One generic test (à la #3b) that pins a
      per-type `{schema_version, shape}` catalog and fails if an event's current
      shape diverges from its pinned entry, forcing a conscious `event_version`
      bump on any change. The shape signature must be **recursive** — many
      events carry nested sub-maps (`ServerUpdated`'s `owner` /
      `expected_properties`, `StudentUpdated`'s `class`, …), so a top-level key
      check is insufficient — see [#6b Event-shape drift
      guard](#6b-event-shape-drift-guard).

### G. Curated read views

Group E fixed the _producer_ side of the read-view coupling: `refresh!`-feeding
broadcasts now carry curated **events**, not raw aggregates. But the _consumer_
still merges each event into the **producer's aggregate schema** held in socket
assigns — so the web layer keeps a `%Server{}` complete with `secret_key`, a
field it never reads (its only readers are server-side: `Token.sign` in
`server_manager_state`, `Token.verify` in `server_callbacks`). A per-server
token sitting in every dashboard/admin LiveView and the user channel is one
stray `inspect` / crash dump / state serialization from disclosure. Two coupled
fixes: give the web layer a curated projection (`ServerView`) that omits it, and
finish E's broadcast-shape story — create/delete are the last raw-aggregate
holdouts (`{:server_created, %Server{}}` / `{:server_deleted, %Server{}}`).

- [x] **#7 `ServerView` read model + broadcast-shape uniformity (Servers
      exemplar).** Hold a curated `ServerView` (no `secret_key`; the nested
      `group` / `owner` **reuse** the existing curated read-views rather than
      flattening — see the detail section) in the web layer instead of
      `%Server{}`, and **relocate — not duplicate — `refresh!` onto it**: all
      five `Server.refresh!` callers are web-layer with no server-side caller,
      so `Server.refresh!` is deleted. Normalize the create/delete broadcasts to
      `{event, reference}` carrying the curated `ServerCreated` /
      `ServerDeleted` event (both already built and persisted by the
      create/delete use cases) — never a bare id, which would be a third
      envelope shape defeating the single-shape invariant; `:server_deleted`
      consumers read only the id from the event today, and `:server_created`
      consumers fetch a `ServerView` on first sighting, reusing the
      fetch-on-appearance path #5c-iii added). Do the read-model and
      broadcast-shape halves in one pass — they meet at the consumers, so
      splitting them touches each twice — see [#7 Curated read views +
      broadcast-shape
      uniformity](#7-curated-read-views--broadcast-shape-uniformity).
- [ ] **#7b Sweep the remaining read models.** Apply the #7 pattern to the other
      purely-web-consumed schemas (`StudentView`, `ClassView`, …). **Only where
      a schema has no server-side `refresh!` caller** — `ServerGroup` is
      excluded (the tracking manager holds the real aggregate and merges
      `group_updated` into it) — see [#7b Sweep the remaining read
      models](#7b-sweep-the-remaining-read-models).

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
- **#5c published payload.** **Reuse the existing domain events** as the contract
  rather than declaring new shapes where one exists — they are already named,
  implement the `Event` protocol, and (being persisted as immutable JSON) are
  forced to stay backward-compatible, exactly the stability a published contract
  needs. The runtime audit resolves the field gaps and the earlier open question:
  - **Uniform rule, no intra-context exception.** Convert **every**
    `refresh!`-feeding broadcast (intra- and cross-context) to carry the event.
    Leaving intra-context broadcasts on the raw schema is a latent trap: the day
    another context subscribes to that topic it silently couples on ORM
    internals — the exact smell #1/#5 exist to prevent. A single invariant
    ("`refresh!` matches a domain event, never a `%Schema{}`") is memorable and
    mechanically testable.
  - **`version` + `occurred_at` ride the envelope**, not the event data. Both
    already live on `StoredEvent`; enrich `EventReference` (which today drops
    them in `to_reference/1`) to carry them. Every event's `occurred_at` is
    already pinned to the aggregate's domain timestamp (`set_up_at`,
    `updated_at`, `created_at`), so the merge derives the read-view's
    `updated_at` and every operational timestamp (`set_up_at`,
    `open_ports_checked_at`) from `occurred_at` with no skew.
  - **No enrichment of `ClassUpdated` needed** (supersedes the earlier note):
    `expected_server_properties` already flows through the existing
    `ClassExpectedServerPropertiesUpdated` event, which `ServerGroup.refresh!`
    matches for the props and `ClassUpdated` for the rest.
  - **`secret_key` stays pruned** — never in an event; `refresh!` leaves the
    cached value untouched (verify no broadcast path mutates it).
  - **`last_known_properties`** is the one real field gap: either **enrich**
    `ServerFactsGathered` to carry the derived `ServerProperties` (recommended —
    the structured observation is a better audit record than raw `facts`), or
    **re-derive** it in `refresh!` from the event's `facts`.

  Keep events curated, not full-row snapshots, so #4 ("event log, not event
  sourcing") stays honest — using events as cache-refresh notifications is not
  event sourcing.

- **#5d in-process, not a process.** The subscribe/reconcile responsibility
  moves into the owning context via **plain in-process helpers**
  (`subscribe_<entity>` / `refresh_<entity>` + an `attach_hook(:handle_info)`
  delegator), **not** a per-entity tracking process. A dedicated process (à la
  `ServerManager`) was considered and rejected: unlike a server, a read-model
  has no authoritative server-side state the web can't compute, no fan-out of
  one computation to many viewers, and no lifecycle beyond "someone is viewing
  it" — and a LiveView is already a stateful process, so a second one only adds
  a process per viewer, a message hop, and ~15–18 modules of ceremony for no
  gain. `ServerManager` earns its process because it manages a real external
  resource (SSH/Ansible); the cross-context `refresh!` is a rider on it, not the
  reason it exists.
- **#5d value and scope.** This is **consolidation**, not integrity: #5c already
  removes the silent-break risk (a rename is a visible event change), so #5d's
  win is de-duplicating the subscribe+dispatch across the ~7 web consumers and
  giving the "what feeds this read-model" knowledge one home in the owning
  context. Sequenced **after #5c** (the dispatch matches named events, so
  building it on raw structs would be throwaway). Split the work: **#5d lands
  the helper + one exemplar consumer**; **#5e** sweeps the rest mechanically —
  keeping each a PR readable end-to-end.
- **#6 event schema versioning.** Track event payload shape with a first-class
  `schema_version` **column** (not `meta`, not the type/stream string), resolved
  at write time (default 1) without touching the 35 existing `Event` impls — a
  per-event `event_version/0` or a central registry, **not** `@fallback_to_any`
  (verified: it doesn't fill a missing function on existing impls) — and
  **bumped on every shape change, additive included** — so a stored row's shape
  is identified by a declared tag, never inferred from which keys are present
  (the #1/#5 smell; and key-presence is lossy — it can't tell "not recorded in
  v1" from "recorded null in v2"). A drift-guard test (#6b) forces the bump.
  **Upcasting** (transforming old payloads to the current shape) is **deferred**
  until a reader needs it — recording the version is cheap and honest,
  transforming is YAGNI. Rejected: version in the stream string (breaks the
  aggregate sequence and the hard-coded stream-prefix entity resolution), in the
  type string (fragments type grouping and badge matching; the type is a stable
  logical identity), or inside `data` (pollutes the domain payload).

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

1. **`version == current + 1`** → merge the incoming payload's fields into the
   cached struct _in memory_ (recursing into nested associations);
2. **`version <= current`** → no-op (stale/duplicate broadcast);
3. **catch-all `(%{id}, %{id})`** → re-fetch the whole struct from the DB via
   `fetch_*`.

It is, in effect, a hand-rolled per-schema _incremental projection_: apply
version N+1 to in-memory state, fall back to a full read on a gap. Seven schemas
carry it, but a runtime audit (call sites, not just definitions) found the live
surface is much smaller than the definitions suggest:

- **Two live cross-context merges**, both Course → Servers, both already backed
  by a domain event:
  - `Class → ServerGroup` — `publish_class_updated` (already carries an
    `EventReference`); events `ClassUpdated` +
    `ClassExpectedServerPropertiesUpdated`.
  - `Student → ServerGroupMember` — `publish_student_updated` (no event ref
    today); events `StudentUpdated` (+ `StudentConfigured`, which shares the
    `:student_updated` message).
- **Three live intra-context merges**: `Class ← Class`, `Student ← Student`
  (Course), and `Server ← Server` (Servers, fed by four events: `ServerUpdated`
  for admin edits, plus `ServerFactsGathered` / `ServerSetUp` /
  `ServerOpenPortsChecked` from the real-time tracker — all already persisted).
- **One live cross-context edge that does _not_ merge**:
  `preregistered_user → Course.Student` (Accounts → Course). No `+1` clause
  matches a `%PreregisteredUser{}`, so it always falls through to the DB
  re-fetch. The only change on that broadcast is the account linkage
  (`user_id`), so an in-memory merge is feasible — this is an omission, closed
  in #5c via a curated Accounts linkage event.
- **Dead refreshers** (no runtime caller): `Course.Schemas.User.refresh!`,
  `Servers.Schemas.ServerOwner.refresh!`, `Student.refresh!`'s
  `ServerGroupMember`-producer clause (nothing broadcasts a `ServerGroupMember`),
  and the unreachable intra `%__MODULE__{}` clauses on the two Servers
  read-views. #5c deletes these instead of converting them.

Three problems, all in the DDD-boundary theme:

- **Shape coupling — the in-memory twin of #1.** Each context broadcasts its
  **raw internal aggregate** (`{:class_updated, %Class{}, _}`); the consuming
  read-view pattern-matches the _producer's field names_
  (`Servers.ServerGroup.refresh!` matches `Class`'s `teacher_ssh_public_keys`).
  Undocumented, with no compile-time guard — the same smell as #1 but at the
  broadcast-struct layer.
- **Silent failure.** When a producer renames a field, the `+1` clause stops
  matching and execution falls through to the catch-all DB re-fetch. Correctness
  is preserved, so nothing crashes and no test fails — the optimization dies
  silently and every update degrades to a cross-context DB read. Forgetting a
  field in the `+1` body serves _stale_ UI data until a version-gap re-fetch
  fires. Both fail invisibly. (The `preregistered_user` edge is already in this
  degraded state permanently.)
- **Boilerplate, no abstraction, no tests.** The live schemas re-implement the
  skeleton and re-list every field, with no shared helper and zero `refresh!`
  test coverage.

The fix proceeds in three tasks (#5a → #5b → #5c). This is the dynamic
counterpart to #1's "make the boundary fail loudly in CI."

### #5a `refresh!` round-trip consistency tests

The loud-failure guard, and the safety net that makes #5b and #5c safe to do.
Cover the **five live merges** the runtime audit in
[#5](#5-cross-context-refresh-coupling) found — not the dead refreshers #5c
deletes:

- cross-context: `Servers.ServerGroup` ← `Class`, `Servers.ServerGroupMember` ←
  `Student`;
- intra-context: `Course.Class`, `Course.Student`, `Servers.Server`.

For each, add a `DataCase` test that:

- inserts producer + consumer, bumps the producer to version N+1, then
- asserts `Consumer.refresh!(old_consumer, incoming)` equals a fresh DB fetch of
  the consumer.

Crucially, **make the DB row and the broadcast payload diverge** (e.g. write one
value to the DB but hand `refresh!` a payload carrying a different value), then
assert the result reflects the _broadcast_ value. This proves the in-memory
merge path ran rather than the catch-all re-fetch — otherwise the fallback
silently returns the DB value and the test passes even though the coupling is
broken. A renamed or forgotten field then fails _loudly_ in CI. Add unit tests
for the `<=` no-op and gap-refetch clauses too.

These tests are written against **today's** raw-struct payloads; #5c adjusts
their inputs to the event payloads and _adds_ the new
`preregistered_user`-linkage merge test (that merge does not exist until #5c
creates it). Aligns with the [testing conventions](../app/docs/testing.md),
which deferred `refresh!` coverage to land here.

### #5b Extract the version skeleton

The `version <= current` no-op clause and the catch-all re-fetch fallback are
identical across the live schemas. Pull them into a **plain higher-order
function** (current struct + incoming payload + the envelope version + a `fetch`
function + a field-mapper function), leaving only the per-schema field mapping
at each call site. It must be a plain function, **not a macro** — consistent
with the #3 decision to remove metaprogramming. This is a DRY/readability win;
the actual silent-staleness guard is #5a, which must land first. #5c then moves
the version source to the `EventReference` envelope, so keep the helper reading
the version from its caller rather than off the incoming struct.

### #5c Broadcast the domain events as the published payload

The anti-corruption fix. Instead of broadcasting the raw internal aggregate,
each producing context broadcasts its curated **domain event** (e.g.
`ArchiDep.Course.Events.ClassUpdated`) as the payload of every
`refresh!`-feeding broadcast, so a consumer's `refresh!` matches a declared,
named, producer-owned shape rather than the producer's ORM internals. **Reuse
the events**, do not declare a new shape where one exists: they already
implement the `Event` protocol (`app/lib/archidep/events/store/event.ex`), are
named in ubiquitous language, and — because they are persisted as immutable JSON
— are already forced to stay backward-compatible, which is exactly the stability
a published contract needs.

**The rule: every `refresh!`-feeding broadcast carries the producing context's
domain event, never the raw schema — intra- and cross-context alike.** Leaving
the intra-context broadcasts on the raw schema is a latent trap: the day another
context subscribes to that topic, it silently couples on ORM internals — the
exact smell #1/#5 exist to prevent. A single invariant ("`refresh!` matches a
domain event, not a `%Schema{}`") is memorable and mechanically testable.

Per producer:

- **Course `class_updated`** → broadcast `ClassUpdated` /
  `ClassExpectedServerPropertiesUpdated` (whichever the use case emitted).
  Consumers `Course.Class.refresh!` (intra) and `Servers.ServerGroup.refresh!`
  (cross) each gain a clause per event type. No enrichment of `ClassUpdated`
  needed — the properties flow through the dedicated event.
- **Course `student_updated`** → broadcast `StudentUpdated` /
  `StudentConfigured`. Consumers `Course.Student.refresh!` (intra) and
  `Servers.ServerGroupMember.refresh!` (cross) gain a clause per event type. Add
  the missing `EventReference` to `publish_student_updated`.
- **Servers `server_updated`** → broadcast `ServerUpdated` (admin edit) and the
  three tracker events `ServerFactsGathered` / `ServerSetUp` /
  `ServerOpenPortsChecked` (all already persisted). `Server.refresh!` matches
  all four. The operational timestamps (`set_up_at`, `open_ports_checked_at`)
  come from the envelope's `occurred_at`, which is already pinned to them at
  emit; the one real field gap is `last_known_properties` — **enrich**
  `ServerFactsGathered` to carry the derived `ServerProperties` (recommended;
  the structured observation is a better audit record than raw `facts`), or
  **re-derive** it in `refresh!` from the event's `facts`. The enrich path
  changes `ServerFactsGathered`'s stored shape (→ `schema_version` 2), so it
  depends on **#6** landing first.
- **Accounts `preregistered_user_updated`** → introduce a small curated linkage
  event (student id + user-account id + username + active) and a
  `Course.Student.refresh!` clause that merges `user_id` / `user` in memory,
  closing the omission where the edge currently always re-fetches.

**Envelope.** Enrich `EventReference` (which today drops them in
`to_reference/1`) to carry `version` and `occurred_at`, both already on
`StoredEvent`. `refresh!`'s version arithmetic and the read-view's `updated_at`
read from the envelope. Every event's `occurred_at` is already pinned to the
aggregate's domain timestamp, so this introduces no skew (see [Decisions
settled](#decisions-settled)).

**Prune `secret_key`** — never in an event; `refresh!` leaves the cached value
untouched. Verify no broadcast path mutates it (it appears creation-only); if
one does, that path needs its own curated event.

Largest change; sequenced last, behind the #5a safety net. Touches the
`pub_sub.ex` modules (`course`, `accounts`, `servers`), `EventReference`, the
relevant `*/events/*.ex` structs, and every live consumer `refresh!`; also
**delete the dead refreshers** listed in
[#5](#5-cross-context-refresh-coupling). This is consistent with #4: using
events as _notification payloads to refresh a cache_ is not event sourcing
(state stays in the DB; nothing is rebuilt from the stream) — provided the
events stay curated and are **not** bloated into full-row state snapshots.

**Open implementation points:** (1) `last_known_properties` — enrich
`ServerFactsGathered` vs re-derive in `refresh!` (the enrich path requires **#6**
first); (2) confirm `secret_key` is never broadcast-mutated.

### #5d Consolidate subscribe + reconcile behind the context

After #5c the broadcast payloads are named events, but the _consumer_ side of the
coupling is still in the web layer: every LiveView/channel that keeps a read-model
live enumerates the relevant message shapes in its `handle_info` clauses and
repeats the cross-context subscription set. Seven web modules (`admin_live`,
`classes_live`, `class_live`, `student_live`, `dashboard_live`, `profile_live`,
`user_channel`) duplicate this, and each encodes that, e.g., a `Course.Student` is
kept live by an Accounts event — knowledge that belongs in the Course context, not
spread across the web layer.

Move it behind two context functions per live read-model:

- `Context.subscribe_<entity>(entity) :: :ok` — subscribes the **calling** process
  to every topic relevant to that entity (its own context's topics plus any
  cross-context ones), so the web layer never names them.
- `Context.refresh_<entity>(entity, message) :: {:ok, entity} | :ignore` — owns
  the message-shape → `refresh!` dispatch (matching the named events from #5c),
  returning the reconciled struct or `:ignore` for an unrelated message.

The web side becomes a single generic delegator — a plain (non-macro)
`ArchiDepWeb.LiveRefresh` helper built on `Phoenix.LiveView.attach_hook/4` at the
`:handle_info` stage:

```elixir
def attach(socket, key, refresher) do
  attach_hook(socket, {:refresh, key}, :handle_info, fn msg, socket ->
    case refresher.(socket.assigns[key], msg) do
      {:ok, updated} -> {:halt, assign(socket, key, updated)}
      :ignore -> {:cont, socket}
    end
  end)
end
```

The hook runs before the LiveView's own `handle_info` clauses and only `:halt`s on
messages the context claims (`:cont` passes everything else through, so unrelated
handlers and multiple tracked entities compose cleanly — no catch-all). The
LiveView calls `Context.subscribe_<entity>` on connected mount and
`LiveRefresh.attach(socket, :entity, &Context.refresh_<entity>/2)`; it names no
events.

**Collections.** Some consumers refresh an element of a list, not a single
assign (`classes_live` refreshes the matching class in a list; `student_live`
tracks student + class + server*group + active_server at once). Add a
`track_collection` variant that finds the matching id and applies the same
single-entity `refresh*<entity>/2`, so the context functions stay single-entity.

**In-process only** — no per-entity tracking process; see [Decisions
settled](#decisions-settled) for why the `ServerManager`-style process was rejected
here.

**Split.** #5d lands the `LiveRefresh` helper, the `subscribe_` / `refresh_`
functions for **one** read-model, and that one consumer converted end-to-end (with
its LiveView test asserting a broadcast still drives the re-render). #5e then
converts the remaining consumers mechanically against the established pattern.

### #5e Sweep the remaining consumers

Convert the rest of the web consumers to the #5d pattern — replacing their
per-event `handle_info` clauses and inline subscriptions with
`Context.subscribe_<entity>` + `LiveRefresh.attach`. Purely mechanical once #5d
sets the exemplar; kept separate so each PR stays readable end-to-end.

### #6 Record a `schema_version` per stored event

The Events store keeps immutable domain events; because nothing rewrites history,
every change to an event's payload shape leaves older rows in their original shape
indefinitely. Today the only way to tell which shape a stored row has is to
inspect which keys are present — the same infer-shape-from-structure smell #1/#5
remove elsewhere, and a lossy one (an absent `last_known_properties` can't be told
apart from a recorded-but-null one). Record the shape explicitly.

- **Column.** Add `schema_version` (integer, `not null`, default `1`) to the
  `events` table; backfill existing rows to `1` (they are the v1 shape). A
  first-class, indexable column — chosen over stuffing it in `meta` — so it is
  queryable for future backfills/analytics and clearly separate from the
  existing per-stream `version` (the optimistic-lock sequence, a different
  concept).
- **Declaration.** Resolve the version (default 1) at write time in
  `add_to_stream/2` and stamp the column — per-type value, stored per-row,
  immutable once written. **Do not put it on the `Event` protocol via
  `@fallback_to_any`:** verified against the code, that only covers types with
  _no_ impl at all, not a missing function on the 35 existing `defimpl Event`
  blocks — adding `event_version/1` to the protocol would force a one-liner into
  all 35 (compile warnings otherwise). Two churn-free options instead:
  - **(B) per-event override + reflective default** — only a bumped event
    defines `def event_version, do: 2` (co-located with the struct);
    `add_to_stream/2` falls back to 1 via `function_exported?/3`.
  - **(D) central `type → version` registry** in `lib/`, read at write time —
    and reused as #6b's pinned catalog, so a version bump and its shape record
    live in one place and cannot diverge (the drift guard also asserts the
    registry lists every `Event` impl).

  Lean **(B)** for lowest churn / co-location; **(D)** if unifying #6 stamping
  with #6b's shape history into one enforced catalog is worth the central list.

- **Policy: bump on every shape change, additive included.** The version is the
  sole discriminator of shape; consumers branch on it, never on key presence.
  This is orthogonal to the additive-only convention (which keeps old rows
  _readable_); the version keeps them _identifiable_.
- **No upcasting yet.** Record the version now; defer transforming old payloads
  to the current shape until a reader actually needs it (there is none today —
  the admin event pages dump `data` generically). When the first breaking change
  lands, add a per-`{type}` upcaster chain keyed on `schema_version`, applied on
  read in `fetch_events` before display.

Prerequisite for the `ServerFactsGathered` enrichment in #5c (that enrichment is
the first `schema_version` bump, 1 → 2), so #6 lands before it.

### #6b Event-shape drift guard

A `schema_version` is only trustworthy if it is actually bumped whenever the
shape changes, and nothing in the compiler enforces that. Reconstruct the
guarantee with a test, exactly as #3b does for the behaviour/boundary/impl trio:
enumerate every `Event`-implementing module (via the consolidated protocol's
`__protocol__(:impls)`) and pin a checked-in per-type `{schema_version, shape}`
catalog. Build the same map at runtime — `%{module => {event_version, shape}}`
for the live impl set — and compare it whole (`==`) to the catalog. A shape
change at the same version, a version bump without a matching catalog edit, or
an added/removed event all fail the single assertion, mechanically forcing the
developer to touch the catalog; the small, reviewable diff (shape changed but
version unchanged vs. both changed) is what enforces the _bump_, since no test
can distinguish a legitimate re-bless from a shape edit without a version
change. The catalog doubles as a reviewed record of every event's current shape.
Lives in
[`test/archidep/events/store/event_schema_version_drift_test.exs`](../app/test/archidep/events/store/event_schema_version_drift_test.exs).

The shape signature is **structural and recursive**, not a top-level `Map.keys`
comparison: many events carry nested sub-maps — `ServerUpdated` embeds `group`,
`owner` and a 13-key `expected_properties`; `StudentUpdated` embeds `class`;
`ServerFactsGathered` embeds `group` / `owner` — and a change _inside_ a sub-map
(e.g. a new key on `owner`) fails the guard too. It is derived from the declared
`@type t` typespec via `Code.Typespec` (the same technique #3b relies on),
rendered to a canonical string with fields sorted and nested maps, unions, lists
and typed-key maps (`%{String.t() => term()}`) expanded recursively.

**Decisions on the two open points:** (1) signature source — the `@type t`
typespec (no per-event sample builder), not a `Jason`-encoded canonical sample.
(2) shared types — same-module type aliases are **inlined** (the sole one,
`UserImpersonated.account/0`, so a change to it fails at `UserImpersonated`);
references to types defined in _another_ module (e.g.
`ArchiDep.Servers.Types.ansible_variables/0`, or the cross-event
`UserImpersonated.account/0` reference in `UserStoppedImpersonating`) are pinned
**by reference**, so a change to such a type is caught where it is defined
rather than at every referrer.

### #7 Curated read views + broadcast-shape uniformity

Group E fixed the producer side of the read-view coupling (broadcasts carry
curated events, not raw aggregates); this closes the consumer side and removes a
sensitive field from web-process memory. Today each consumer merges the event
into the producer's aggregate schema kept in socket assigns, so a `%Server{}` —
`secret_key` included — lives in every dashboard/admin LiveView and the user
channel. The web layer never reads `secret_key`; its only readers are
server-side (`Token.sign` in `server_manager_state.ex`, `Token.verify` in
`server_callbacks.ex`). A per-server token in long-lived web state is one stray
`inspect`, crash dump, or LiveView state serialization from disclosure.

**`refresh!` is a read-model operation, currently misplaced on the aggregate.**
It means "apply a curated event to my in-memory read projection," and it lives
on `Server` only because the schema doubles as the read model today. Introduce a
curated `ServerView` and `refresh!` moves onto it, leaving the schema a pure
persistence concern. For `Server` this is a **relocation, not a duplicate**: all
five `Server.refresh!` call sites are web-layer (`admin_live`,
`my_servers_live`, `student_live`, `dashboard_live`, `user_channel`) with no
server-side caller, so `Server.refresh!` is deleted rather than kept in
parallel.

**The move is not uniform — `ServerGroup` is the counter-example.** Two of the
five `refresh!` definitions still have a server-side caller:
`ServerGroup.refresh!` is invoked from `server_manager_state.ex` (the tracking
manager holds the real `%ServerGroup{}` — it needs the authoritative aggregate,
`secret_key` and all — and merges `group_updated` into it). That process must
not hold a view. Rule: a schema's `refresh!` moves onto its view **only when the
schema is purely web-consumed**; a schema also held server-side keeps `refresh!`
on the aggregate.

**`ServerView` reuses the nested read-views; it does not flatten them.**
Faithful flattening is impossible: `Server.active?/2` — which `student_live` and
`user_channel` call to decide list membership — reads
`group.{active,start_date,end_date}`, `owner.{root,active}` and
`owner.group_member.{active,group_id}` and is time-dependent (`Clock.now()`), so
those associations carry business-logic inputs, not just display strings (a
precomputed `active?` boolean would go stale at date boundaries). And #7b keeps
`ServerGroup` as an aggregate read-view (a server-side caller holds the real
`%ServerGroup{}`), so the group cannot be replaced by a display map.
`ServerView` therefore embeds the existing `ServerGroup` / `ServerOwner` (with
its `ServerGroupMember`) read-views unchanged, and its `refresh!` fans **in**
events from several source aggregates: a server event updates the server-level
fields; a class event delegates to `ServerGroup.refresh!`; a student event
delegates to `ServerGroupMember.refresh!`. A larger merge surface than
`Server.refresh!`, which handled only server events — this is why #7 is a bigger
increment than #5c-iii, not a mechanical rename.

**Implementation status (complete).** `ArchiDep.Servers.ServerView` exists with
`from/1`, `refresh!/3` (dispatching over server / class / student events),
`active?/2` and the display helpers; the four web-only context reads
(`fetch_server`, `list_my_servers`, `list_all_servers_in_group`,
`fetch_active_server_for_group_member`) return `ServerView` (server-side
projection drops `secret_key`); `admin`'s `list_all_servers_in_group` now
full-preloads the graph so the view is uniformly complete; create/delete
broadcasts carry `ServerCreated` / `ServerDeleted` as `{event, reference}`;
every consumer, the shared server components, the edit/delete dialogs and
`ServerForm` hold `ServerView`; the tracker client accepts a `trackable`
(`Server.t() | ServerView.t()`); and `Server.refresh!` is deleted.
`ServerFactsGathered` and `ServerOpenPortsChecked` are version-only bumps on the
view (their fields are not rendered). The app compiles with
`--warnings-as-errors`, passes `mix credo --strict` and `mix dialyzer`, and the
full test suite is green. The relocated `refresh!` round-trip tests live in
`test/archidep/servers/server_view_test.exs`; the web component / LiveView /
channel test fixtures were migrated to `%ServerView{}` (via a
`ServersFactory.build_server_view/1` helper that projects a built `:server`) and
the use-case broadcast assertions to `{event, reference}`. The migration also
surfaced three consumers of the create/delete broadcasts that needed the new
tuple shape — `class_live`'s `handle_info`, the `ServersOrchestrator`, and the
`watch_server_ids` reducer.

**Two halves, done together.**

- **Broadcast-shape uniformity.** Stop putting `%Schema{}` on PubSub for
  create/delete too — broadcast the curated `ServerCreated` / `ServerDeleted`
  event (both already built and persisted by the create/delete use cases) as
  `{event, reference}`, uniform with `:server_updated`. Not a bare id for
  delete: a third envelope shape defeats the single-shape invariant the whole
  group exists to hold, and the day a consumer wants the deleted server's name
  (a flash, say) a bare id forces a broadcast-shape change. Consumers read only
  `event.id` from `:server_deleted` today (`untrack` and list-reject need
  nothing more). `:server_created` has no prior state to merge, so consumers
  **fetch a `ServerView` on first sighting** — the same fetch-on-appearance path
  #5c-iii added for updates arriving before a create.
- **Curated read model.** The web layer holds `ServerView`, never `%Server{}`;
  make it the only server type the web layer sees so typespec/compiler pressure
  keeps the projection from drifting from the schema.

The two meet at the consumers, so splitting them touches each consumer twice —
do them in one pass per context.

**Sequencing.** Interacts with #5d/#5e: #5d's `Context.refresh_server/2` should
return a `ServerView`, so land #7 (or its Servers slice) with or before the
Servers exemplar in #5d — otherwise #5d builds the consolidated refresher
against the aggregate and #7 rewrites it. #7b then sweeps the other
purely-web-consumed schemas.

**Status: proposed, not yet scheduled.** The payoff is a real defense-in-depth
gain (a sensitive token leaves long-lived web memory) plus the honest read/write
split, weighed against a sizeable typing sweep — every server-rendering
component and template retyped to `ServerView` — and the fan-in `refresh!`
above. Schedule it if the secret-in-memory exposure is judged material; the
cheap half (normalizing the create/delete broadcasts to the curated
`ServerCreated` / `ServerDeleted` event) can land on its own if only broadcast
tidiness is wanted.

### #7b Sweep the remaining read models

Once #7 sets the `ServerView` pattern, apply it to the other purely-web-consumed
schemas (`StudentView`, `ClassView`, …), moving each `refresh!` off the
aggregate and onto its view. Gate strictly on the #7 rule: convert a schema
**only when it has no server-side `refresh!` caller**. `ServerGroup` is excluded
— the tracking manager (`server_manager_state.ex`) merges `group_updated` into a
real `%ServerGroup{}` — so its `refresh!` stays on the aggregate and no
`ServerGroupView` is introduced for it. Mechanical once #7 is in place; kept
separate so each PR stays reviewable.

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
