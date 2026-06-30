# Phoenix application testing — plan to reach 90% coverage

The testing foundation is strong, modern, and essentially complete: every layer
already has a working, demonstrated pattern, contract-checked mocks, and
per-context factories. The detailed assessment that backs this conclusion is
preserved at the [bottom of this document](#assessment-background). This top
section turns that conclusion into a concrete, reviewable backlog.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [How to use this backlog](#how-to-use-this-backlog)
- [Backlog](#backlog)
- [Tasks](#tasks)
- [Assessment (background)](#assessment-background)

<!-- END doctoc -->

---

## How to use this backlog

Two rules shape every task below:

1. **Each task is a reviewable chunk.** No task bundles "all DataCase tests" or
   "all admin LiveViews" — those are unreviewable. Chunks are scoped to a
   handful of related files (one feature, one set of use cases) so a single PR
   can be read end-to-end. Counts/files in scope are listed per chunk.

2. **Each layer opens with a canon-setting task (🧭).** Before sweeping a layer
   at scale, the first task for that layer is a deliberately small spike:
   **analyze the current practices in that layer, write a few representative
   tests, get them reviewed by a human, then refactor — repeat until we agree on
   the canonical way to write tests for that layer.** Only once a 🧭 task is
   signed off do the follow-up chunks for that layer become "just apply the
   pattern." If a follow-up chunk reveals the canon is wrong, fix the canon
   first.

Suggested ordering: **Foundations → Business layer → Web layer → Channels →
Plumbing → Helpers**. Foundations unblock everything; the business layer holds
the densest untested logic; the web layer is the largest by file count but is
mostly mechanical once its canon is set.

Pick the next unchecked task, implement it as one reviewable chunk, and check
the box once you consider it complete (tests passing, formatted, linted). A
human reviews afterward and will flag anything missed.

**Coordinating with the DDD plan.** A few chunks here touch code that
[`ddd.md`](./ddd.md) refactors — the `refresh!` functions, the server-count
columns on `user_accounts`, and the PubSub broadcast shapes. To avoid writing
those tests twice, write **black-box behavioral** tests now and defer those
three structural slices to ship with the DDD tasks that finalize them. See
[Sequencing with the testing plan](./ddd.md#sequencing-with-the-testing-plan) in
`ddd.md` for the full ordering.

---

## Backlog

This is the bird's-eye view: each item links to its full description under
[Tasks](#tasks). The checkboxes are the single source of truth for what is done.

- **0. Foundations (do these first)**
  - [x] [Shared auth/setup fixtures](#shared-authsetup-fixtures)
  - [x] [Add a `ChannelCase`](#add-a-channelcase)
  - [x] [Coverage config & regression ratchet](#coverage-config--regression-ratchet)
- **1. Business layer — contexts, use cases, schemas**
  - [x] 🧭 [Canon — business-layer test conventions](#canon--business-layer-test-conventions)
  - [x] [Roll out the row-count-diff assertion](#roll-out-the-row-count-diff-assertion)
  - [x] [Course — class use cases (remainder)](#course--class-use-cases-remainder)
  - [x] [Course — student use cases](#course--student-use-cases)
  - [x] [Course — student import](#course--student-import)
  - [x] [Course — remaining schemas](#course--remaining-schemas)
  - [x] [Course — backfill exhaustive schema validation tests](#course--backfill-exhaustive-schema-validation-tests)
  - [x] 🧭 [Canon — accounts auth use cases](#canon--accounts-auth-use-cases)
  - [x] 🔒 [Security invariant — login links never authenticate a root account](#security-invariant--login-links-never-authenticate-a-root-account)
  - [x] [Accounts — session lifecycle use cases](#accounts--session-lifecycle-use-cases)
  - [x] [Accounts — schemas](#accounts--schemas)
  - [x] [Events context](#events-context)
  - [x] [Servers — context use cases](#servers--context-use-cases)
  - [x] [Servers — tracking-coupled use cases](#servers--tracking-coupled-use-cases)
  - [x] [Servers — `Server` schema validations](#servers--server-schema-validations)
  - [x] [Servers — `Server` persistence functions & helpers](#servers--server-persistence-functions--helpers)
  - [x] [Servers — `ServerProperties` schema](#servers--serverproperties-schema)
  - [x] [Servers — `AnsiblePlaybookRun` schema](#servers--ansibleplaybookrun-schema)
  - [x] [Servers — `AnsiblePlaybookEvent` schema](#servers--ansibleplaybookevent-schema)
  - [x] [Servers — Ansible `Tracker` persistence & events](#servers--ansible-tracker-persistence--events)
  - [x] [Servers — small schema leftovers](#servers--small-schema-leftovers)
- **2. Web layer — LiveViews & controllers**
  - [x] 🧭 [Canon — web-layer LiveView test conventions](#canon--web-layer-liveview-test-conventions)
  - [x] [Servers web — server detail & dialogs (remainder)](#servers-web--server-detail--dialogs-remainder)
  - [x] [Servers web — forms & components](#servers-web--forms--components)
  - [x] [Servers web — controllers & retry handlers](#servers-web--controllers--retry-handlers)
  - [x] [Admin — classes list/detail + class dialogs](#admin--classes-listdetail--class-dialogs)
  - [x] [Admin — class form components](#admin--class-form-components)
  - [x] [Admin — students list + student dialogs](#admin--students-list--student-dialogs)
  - [x] [Admin — student form components](#admin--student-form-components)
  - [x] [Admin — events views](#admin--events-views)
  - [x] [Admin — ansible views](#admin--ansible-views)
  - [x] [Admin — top-level shell](#admin--top-level-shell)
  - [x] [Dashboard](#dashboard)
  - [x] [Profile (remainder)](#profile-remainder)
- **3. Channels**
  - [x] 🧭 [Canon + tests — channels](#canon--tests--channels)
- **4. Plumbing — router, plugs, auth controller**
  - [x] 🧭 [Canon + tests — auth controller & plugs](#canon--tests--auth-controller--plugs)
- **5. Helpers & components**
  - [x] 🧭 [Canon — components & web helpers](#canon--components--web-helpers)
  - [x] [Web helpers (remainder)](#web-helpers-remainder)
  - [x] [Shared components](#shared-components)
- **6. Runtime processes — server tracking & Ansible pipeline (integration)**
  - [x] 🧭 [Canon — testing runtime processes](#canon--testing-runtime-processes)
  - [x] [Ansible pipeline — Runner & GenStage](#ansible-pipeline--runner--genstage)
  - [ ] [Server tracking — SSH connection](#server-tracking--ssh-connection)
  - [ ] [Server tracking — orchestrator & Tracker](#server-tracking--orchestrator--tracker)
- **7. Finalize coverage policy (do this last)**
  - [ ] [Decide exclusions](#decide-exclusions)
  - [ ] [Lock the global threshold](#lock-the-global-threshold)
  - [ ] [(Optional) Per-critical-path enforcement](#optional-per-critical-path-enforcement)

---

## Tasks

The detailed description of every backlog item. Each heading is the target of a
link in the [Backlog](#backlog); to mark a task done, tick its checkbox in the
backlog list, not here.

### Shared auth/setup fixtures

_Context:_ the foundations tasks are small, self-contained, and make every later
chunk faster or the 90% target honest. Can be a single PR or three small ones.

Add named `ExUnit` setup helpers to `ConnCase`/`LiveCase` (e.g.
`register_and_log_in_root`, `register_and_log_in_student`) returning
`%{conn, auth, user_account, session}`, usable as
`setup :register_and_log_in_root`. Replace the hand-rolled ~15-line boilerplate
in `profile_live_test.exs` to prove it out. This roughly halves every future web
test. _Files:_ `test/support/conn_case.ex`, `test/support/live_case.ex`,
`profile_live_test.exs`.

### Add a `ChannelCase`

`user_channel.ex` / `user_socket.ex` have no `Phoenix.ChannelTest` support. Add
the case template (no tests yet — those land in the [Channels](#canon--tests--channels)
task). _Files:_ `test/support/channel_case.ex`.

### Coverage config & regression ratchet

There is no `coveralls.json`. Add one — but **do not `skip_files` anything yet**.
We want every file in the denominator while we sweep, and will revisit
exclusions only at the end (see [Decide exclusions](#decide-exclusions)) once we
can see real coverage. For now, set `minimum_coverage` to a ratchet: start it at
the current project coverage (~65%) and bump it upward as chunks land so
coverage can never regress in CI, without demanding 90% before the work is done.
_Files:_ `app/coveralls.json`. _Note:_ ExCoveralls' `minimum_coverage` is a
single **global aggregate** (no per-file/per-directory thresholds) — the
critical-path policy is handled in
[(Optional) Per-critical-path enforcement](#optional-per-critical-path-enforcement).

### Canon — business-layer test conventions

_Context:_ the business layer is tested with DataCase + the real `UseCases.*`
modules (optionally wrapped in `Hammox.protect/2`) + insert factories.
Exemplars: `log_in_or_register_with_switch_edu_id_test.exs` (use case + DB +
events), `class_test.exs` / `student_test.exs` (schemas).

🧭 Take the **course class use cases** (`CreateClass`, `ReadClasses`,
`UpdateClass`, `DeleteClass`, `UpdateExpectedServerPropertiesForClass`) and
write tests for two or three of them. Settle the conventions: when to call the
use case directly vs. through the facade, whether/how to `Hammox.protect/2` the
real impl, how to assert emitted events
(`fetch_new_stored_events`/`assert_no_stored_events!`), authorization/policy
assertions, and factory usage. Get reviewed, refactor, agree. Output: a short
"how we test the business layer" note + the reviewed example tests. _Progress:_
`create_class_test.exs` has landed as the first course-class exemplar, following
the three-test create strategy now documented in `docs/testing.md` (random /
minimal / full) plus the authorization, validation, uniqueness, and PubSub
branches. The conventions refined on the accounts auth use cases transferred
cleanly. Findings from the spike, all resolved: (1) the course path was not yet
clock-injected, so `Class.new/1` became `Class.new/2` taking `now` (use case
calls `Clock.now/0`), matching Accounts; (2) writing the "full" test surfaced
two latent bugs where the SSH host-key fingerprints had been added to the schema
but not propagated — the `ClassCreated` event and the `class_data` type both
omitted them; both fixed (the event now carries them and the type lists them).
`UpdateClass` has since landed as the second exemplar, and the update-testing
strategy is now documented in `docs/testing.md` (update-everything /
clear-every-optional / random, plus the not-found, same-name-succeeds, and
optimistic-lock-not-unit-testable branches). The same two gaps recurred on the
update path and were fixed the same way: `Class.update/2` became
`Class.update/3` taking `now` (use case calls `Clock.now/0`), and the
`ClassUpdated` event now carries the SSH host-key fingerprints so the row is
fully reconstructable from the event. `ReadClasses` then landed as the **query**
exemplar — settling the conventions the command tests did not cover (ordered
lists asserted by full-list equality with every `ORDER BY` key pinned,
date-window filtering with inclusive boundaries, and the existence-masking
`fetch_class` branch) — and is documented in `docs/testing.md` under "Testing
read use cases". The recurring clock gap appeared once more:
`list_active_classes` derived "today" from `Date.utc_today()` and now uses
`DateTime.to_date(Clock.now/0)`. With the command and query conventions now
settled, documented, and reviewed across these three exemplars, this box is
checked. `DeleteClass` and the rest are ordinary work under [Course — class use
cases (remainder)](#course--class-use-cases-remainder) — not a canon blocker.

### Roll out the row-count-diff assertion

_Context:_ checklist item 4 ("Pinned row counts: no stray inserts") and the
delete/persistence assertions are currently expressed by asserting the
database's _absolute_ state (`[only_one] = Repo.all(Schema)`, `Repo.all(Schema)
== []`), which reads as semantically off — the meaningful statement is what a
use case _changed_. A `DataCase` helper now expresses that as a difference:
`count_rows([…])` snapshots the watched tables before the call and
`assert_row_count_diff(counts, %{Schema => delta})` asserts each watched table
changed by exactly its delta (unlisted watched tables must be unchanged). It was
introduced and proven on `delete_class_test.exs` and
`update_expected_server_properties_for_class_test.exs`, in two complementary
roles: a **non-zero diff** on success paths (the deletion is `%{Class => -1,
ExpectedServerProperties => -1, StoredEvent => 1}`), and an **all-zero diff** on
every no-effect / side-effect-free path that has a fixture the call could have
touched (rejected mutations and — most importantly — the side-effect-free
`validate_*` functions, where "writes nothing" is the whole contract). The
all-zero diff complements, not replaces, the exact `persisted_class == original`
content check: the content check pins the one known row, the diff catches a
stray insert or delete anywhere in the watched tables. (Pure not-found paths,
which insert no fixture, skip it — an all-zero diff over empty tables proves
nothing; `assert_no_stored_events!/0` covers them.)

This task makes it the canon: (1) document it in `docs/testing.md` (the "What a
business-layer test must assert" checklist, the create/update/delete sections,
and the "absence of out-of-band effects" section for the all-zero no-effect/
validate usage) as the standard way to assert row counts, replacing the
absolute-state phrasing; (2) roll it back through the already-written exemplars
(`create_class_test.exs`, `update_class_test.exs`, the accounts auth tests) so
they assert deltas instead of `[only_one] = Repo.all(…)`; (3) apply it as the
default in every later business-layer chunk. _Scope:_ `docs/testing.md` + the
existing business-layer test files. _Files:_ `test/support/data_case.ex` (helper
already landed).

_Done:_ documented as canon — checklist item 4, the "exact assertions on
database side effects" section (the `[only_one] = Repo.all(…)` recommendation is
replaced with the snapshot/diff approach), the "absence of out-of-band effects"
section (all-zero diff on no-effect/validate paths), and the delete section now
point at `count_rows/1` + `assert_row_count_diff/2` /
`assert_no_row_count_diff/1`. The `assert_no_row_count_diff/1` convenience
wrapper landed alongside. Converted the pure-count `[only_one]`/`[_only_one]`
and no-effect count assertions in `create_class_test.exs`,
`update_class_test.exs`, `create_login_links_test.exs`, and
`log_in_or_register_with_link_test.exs` (success paths assert the
creation/update delta; rejected and side-effect-free paths assert an all-zero
diff). **Deliberately left:** content/identity assertions that bind the actual
rows (`[^row] = Repo.all(…)`, `Repo.all(…) == [struct]`) — a count diff is
weaker than pinning the row, so those stay.

_Follow-up (review feedback):_ the first pass watched too few tables per call
and skipped many tests, which defeats the check. Resolved by adopting an
`@affected_tables [...]` module attribute per test file — the full set of tables
the use case can affect (writes plus adjacent tables it must leave alone, always
including `StoredEvent`) — passed to **every** `count_rows/1` snapshot. The diff
in each test now only spells out the non-zero deltas; everything else in
`@affected_tables` is pinned unchanged. Applied to all six business-layer
use-case test files, comprehensively (every success, rejected, and not-found
path now snapshots and asserts), including the previously-skipped
`log_in_or_register_with_switch_edu_id_test.exs`. This caught the real
under-specification: `log_in_or_register_with_link_test.exs` had watched only
`UserAccount`, missing the `UserSession` and `StoredEvent` each login creates.
`count_rows/1` was left generic (it does **not** auto-add `StoredEvent`) — the
`@affected_tables` list is the single, explicit "don't forget a table"
mechanism. Convention documented in `docs/testing.md`.

### Course — class use cases (remainder)

Finish any of the 5 class use cases not written during the canon task. _Scope:_
`course/use_cases` class-related modules. _Done:_ the two remaining use cases
are covered — `delete_class_test.exs` (delete: happy path, the
`class_has_servers` foreign-key branch, not-found, authorization) and
`update_expected_server_properties_for_class_test.exs` (a child-association
"sub-aspect" update: update-everything / clear-every / random over the 13
properties, plus the validation, not-found and existence-masking branches, and
the side-effect-free validate function). The work needed **two new
`docs/testing.md` strategies** the create/update/read canon did not cover —
"Testing delete use cases" and "Testing sub-aspect (child-association) update
use cases" — since neither fit the existing sections. It also surfaced and fixed
the recurring issues the canon predicts: the clock gap appeared on both paths
(`DeleteClass` stamped the event with `DateTime.utc_now()`, now `Clock.now()`;
`Class.update_expected_server_properties/2` became `/3` taking `now`, matching
`Class.update`), a latent `WithClauseError` in
`UpdateExpectedServerPropertiesForClass` where the `with/else` swallowed
`{:error, :class_not_found}` and crashed on any unknown id (fixed), and a
validate/mutate authorization asymmetry (validate raised while the mutation
masked) aligned so both existence-mask. Finally, writing a second
`{:class_updated}` broadcaster exposed a **PubSub test-isolation bug**:
assertions on the shared, non-sandboxed `"classes"` topic caught concurrent
tests' broadcasts. All class-use-case broadcast assertions (including the
`create_class`/`update_class` exemplars) now pin the resource id so selective
receive ignores other tests' messages; the convention is documented under
"Asserting PubSub broadcasts". Human review then drove four refinements: (1) the
absolute-state row-count assertions were replaced with a `count_rows` /
`assert_row_count_diff` helper that asserts what the use case _changed_ (the
delete asserts this specific class and its properties row are gone, plus the
table deltas) — proven here and queued for rollout under [Roll out the
row-count-diff assertion](#roll-out-the-row-count-diff-assertion); (2) the
missing **failing** case for the side-effect-free `validate_*` functions was
added to all three of create/update/update-properties, and the gap documented as
a canon rule; (3) a one-off factory-wrapping helper for the blocking-server
fixture was inlined and the "keep factory calls visible" guideline tightened to
cover multi-step setup; and (4) an `expected_server_properties_data` factory
that wrongly delegated to the struct factory was rewritten to build its map
independently, like `class_data_factory`.

### Course — student use cases

`CreateStudent`, `ReadStudents`, `UpdateStudent`, `ConfigureStudent`,
`DeleteStudent`. _Scope:_ 5 modules. _Done:_ all five covered
(`create_student_test.exs`, `read_students_test.exs`, `update_student_test.exs`,
`configure_student_test.exs`, `delete_student_test.exs`) following the
create/update/read/delete strategies. Students were the course context's first
**non-root, self-service** authorization (`configure_student`,
`fetch_authenticated_student`), which drove two new canon rules: how to set up a
persisted self-service principal, and asserting masked errors once per upstream
cause (see [Authorization and
policy](../app/docs/testing.md#authorization-and-policy)). Threading the
injected clock all the way down was also extended into canon (see [Deterministic
time](../app/docs/testing.md#deterministic-time-via-an-injectable-clock)). Three
latent bugs were fixed along the way (flag for review): the student schema and
`delete_student` stamped their own `DateTime.utc_now()` instead of taking
`Clock.now()` from the use case (timestamps were unpinnable); `create_student`'s
`else` masked the wrong action atom (`:validate_student`), so a non-root caller
hit a `WithClauseError` instead of `:class_not_found`; and `configure_student`
used `=` instead of `<-` for `User.fetch_authenticated`, raising `MatchError`
for a principal with no account instead of the masked `:student_not_found`.
_Note:_ deleting a student who has already logged in is unsupported and was
documented as a deferred [known
issue](../app/docs/known-issues.md#deleting-a-student-who-has-logged-in-fails);
the delete test covers only unlinked students.

### Course — student import

`ImportStudents` + `StudentImportList` schema (parsing/validation is
logic-dense; worth its own chunk). _Scope:_ 1 use case + 1 schema. _Done:_ both
covered (`import_students_test.exs`, `schemas/student_import_list_test.exs`).
This is a **bulk create** with no single-record equivalent, so a few assertions
depart from the create canon and are flagged inline: list output matched by
email (`insert_all` order is unspecified); the per-student SSH password bound
and cross-referenced (5 bytes base32 — too short for
`assert_secure_random_token`); the two-level audit trail (one
`StudentsImportedInClass` event plus one `StudentCreated` per new student)
matched by type/id rather than position since all events share `occurred_at`,
with the causation chain asserted; and the generated usernames bound and
cross-referenced in the use-case test (one exact value pinned to anchor the
wiring) while the generation algorithm is pinned exhaustively in the schema
test. Four latent bugs were fixed along the way (flag for review):
`import_students/3` stamped its own `DateTime.utc_now()` instead of taking
`Clock.now()` (timestamps were unpinnable); it called the raising `authorize!/5`
with no `else`, so a non-root caller hit an `UnauthorizedError` instead of the
masked `:class_not_found` its siblings return; the `import_student_data` type
required a `username` field that no caller supplies and the schema ignores (it
generates its own), so the type was corrected to `{name, email}`; and the use
case broadcast `{:students_imported, class, []}` even when every student already
existed and nothing was inserted, so the broadcast is now skipped when no
student was imported (the test verifies no notification is published).

### Course — remaining schemas

`User`, `ExpectedServerProperties` (`Class`/`Student` partially covered — see
the backfill task below). _Scope:_ 2 schemas. _Done:_ `ExpectedServerProperties`
is covered exhaustively (`schemas/expected_server_properties_test.exs`): the
per-field length limits and the numeric bounds for every integer field
(generated once each via a `for` comprehension over the field/limit list), the
`{number}` placeholder asserted literally since the translation layer resolves
it at render time, plus the `trim_to_nil` behavior. **`User` was deliberately
skipped:** it has no changeset/validation functions — only `fetch_user/1`,
`fetch_authenticated/1` and the in-memory `refresh!/2` — so there is nothing to
validate-test. Its query/refresh logic can be covered later if coverage demands.

### Course — backfill exhaustive schema validation tests

The canon makes each Ecto schema's unit test the **exhaustive** source of truth
for its changeset validations, so use-case tests can stay thin (see [Changeset
and validation errors](../app/docs/testing.md#changeset-and-validation-errors)).
The existing `class_test.exs` and `student_test.exs` predate this and cover only
a subset — e.g. `class_test.exs` asserts the `teacher_ssh_public_keys` rules but
not the name length limit or the start/end-date ordering rule. Backfill them so
every validation in `Class` and `Student` is asserted with exact messages,
including each of a schema's changeset functions where they validate differently
(e.g. `Class.new/2` vs. `Class.update/2` vs.
`update_expected_server_properties/2`). New schema tests (`User`,
`ExpectedServerProperties`) should be exhaustive from the start.

_Done:_ `class_test.exs` and `student_test.exs` now assert every changeset rule
with exact messages. Rules shared by the create and update changesets are written
once and generated for both via a `for variant <- [:new, :update]` comprehension
that `unquote`s the variant into each test (a small private builder dispatches to
`new`/`update`); divergent behavior (name/email/username uniqueness with
self-exclusion, and `validate_required`, which cannot fail on the update path)
lives in plain per-variant `describe` blocks. The new `for`+`unquote` convention
is documented in `docs/testing.md` under [Changeset and validation
errors](../app/docs/testing.md#changeset-and-validation-errors). Three bugs were
found and fixed along the way (flag for review):

1. `Class`'s SHA256 host-key-fingerprint validation added its error under
   `:ssh_exercise_vm_host_key_fingerprints` — a non-existent field — so the error
   was silently swallowed and never reached the form (the form already binds the
   correct field). Corrected to `:ssh_exercise_vm_sha256_host_key_fingerprints`;
   no web change needed.
2. `Student.new/3` and `Student.update/3` rejected hyphens in usernames
   (`~r/\A[a-z][a-z0-9]*\z/i`) even though their error message and the
   student-facing dialogs say hyphens are allowed; aligned them with
   `configure_changeset/3` (`~r/\A[a-z][\-a-z0-9]*\z/i`). The stale
   no-hyphen comment in the `student_data` factory was updated, and the admin
   student form's "(alphanumeric)" help text is flagged for the reviewer as now
   slightly inaccurate.
3. _Found but not fixed (separate context):_
   `ArchiDep.Servers.SSH.SSHKeyFingerprint.parse/2` raises a `WithClauseError`
   on a fully-malformed fingerprint line (its `with/else` only handles the
   `{:ok, …}` fallthrough, not `{:error, :malformed}`), so garbage fingerprint
   input crashes the class changeset instead of producing a validation error.
   The schema test sidesteps it by using a well-formed wrong-digest fingerprint.
   Documented in [`app/docs/known-issues.md`](../app/docs/known-issues.md), with
   a note to add a malformed-input test once the parser is fixed.

### Canon — accounts auth use cases

🧭 Auth flows touch sessions, events, and external identity.
`log_in_or_register_with_switch_edu_id_test.exs` already exists as a reference;
extend the canon to `LogInOrRegisterWithLink` and `CreateLoginLinks`, confirm
the conventions hold for the login-link path, get reviewed. _Scope:_ 2–3 use
cases. _Done:_ both login-link use cases are covered —
`log_in_or_register_with_link_test.exs` (consumption, 10 branches) and
`create_login_links_test.exs` (generation, 6 branches), each with the clock
injected. The canon conventions are settled and signed off: pipe-chained
assertion helpers, factory calls kept visible at the call site (with pure
attrs-builders for repeated options), exact assertions, and event/telemetry/
broadcast assertions asserted only where the use case emits them.

### Security invariant — login links never authenticate a root account

🔒 A login link is a bearer token in a URL (it leaks via browser history,
proxy/server logs and `Referer` headers); root is the highest-privilege
principal, so a link must never grant it. Today this holds only by accident —
the account-reuse branch in `LogInOrRegisterWithLink` reuses the linked account
without checking `root`. Enforce it explicitly: in
`log_in_or_register_with_link.ex` match `%UserAccount{active: true, root:
false}` (so a `root: true` account fails closed with `:invalid_link`), and
confirm `CreateLoginLinks` has no path to target a root account. _Tests:_ on the
consumption side, an active root account linked to a preregistered user still
yields `:invalid_link` (with no session, event, telemetry or broadcast); on the
generation side, `CreateLoginLinks` cannot produce a link for a root account.
The break-glass alternative for root users locked out when Switch edu-ID is down
is deliberately _not_ this mechanism — it is tracked separately in
[`app/docs/future-work.md`](../app/docs/future-work.md). _Progress:_ enforcement
has landed in `log_in_or_register_with_link.ex` (the account-reuse clause now
matches `%UserAccount{active: true, root: false}`, so a `root: true` account
falls through and fails closed with `:invalid_link`), covered on the consumption
side by `log_in_or_register_with_link_test.exs` ("a login link must never
authenticate a root account"). The generation side is covered too:
`CreateLoginLinks` structurally only targets a preregistered user (there is no
parameter or code path to a user account), and `create_login_links_test.exs`
pins that the created link carries `user_account_id: nil` even when the student
is linked to a root account — so a link can never be minted for a root account.
Both sides done; box checked.

### Accounts — session lifecycle use cases

`Sessions`, `DeleteSession`, `LogOut`, `Impersonate`. Impersonation has its own
authorization rules — assert them. _Scope:_ 4 use cases.

_Done:_ all four covered (`sessions_test.exs` for `fetch_active_sessions` /
`validate_session_token` / `validate_session_id` / `user_account`,
`delete_session_test.exs`, `log_out_test.exs`, `impersonate_test.exs` for
`impersonate` / `stop_impersonating`). No new `docs/testing.md` section was
warranted: with impersonation now event-emitting, the only no-event in-place
writer left is the session-refresh path (`validate_*` → `touch`), and the
existing canon (the diff pins counts not contents; reload-and-pin the row;
assert the absence of side effects) already covers it. The recurring clock gap
appeared again and was fixed by threading the injected clock (flag for review):
`validate_session_token`/`validate_session_id` and `LogOut` read
`DateTime.utc_now/0` directly (so the refreshed `used_at` and the
logout/deletion events' `occurred_at` were unpinnable), and
`UserSession.touch/2` stamped its own `used_at`; `touch/2` became `touch/3`
taking `now`, and the `delete_session`/`log_out` events now pass `occurred_at:
Clock.now()`. The 30-day validity window itself was also moved onto the injected
clock: the SQL `ago/2` fragment (database clock) was replaced by a cutoff
derived from `Clock.now()` (`fetch_active_sessions_by_user_account_id/1` became
`/2` taking `now`), so the whole window is deterministic and expiry-boundary
tests pin `created_at` relative to the pinned `@now` rather than to wall-clock
time. Each use case covers both a root and a **student** account (the
`AccountsTestHelpers.register_active_student` orchestration sets up the
active-class/active-student/linked-account chain). Three approved semantics
changes landed (flag for review): (1) `delete_session` used the raising
`authorize!`, leaking session existence to a non-owner via `UnauthorizedError`
while an unknown id returned `:session_not_found`; it now masks the unauthorized
path as `:session_not_found` too. (2) Impersonation mutated the session in place
with no audit trail; `impersonate`/`stop_impersonating` now run inside an
`Ecto.Multi` that stores a `UserImpersonated` / `UserStoppedImpersonating` event
and emit `[:archidep, :accounts, :auth, :impersonate]` / `:stop_impersonating`
telemetry (the schema's `impersonate/2` and `stop_impersonating/1` now return
changesets instead of calling `Repo.update!`). Each event embeds the full
account representation other account events use (id, username, root, Switch
edu-ID and preregistered-user sub-maps) for **both** the impersonator and the
impersonated, so the audit log can display a student by name/email — which
needed deeper preloads on `UserSession.fetch_by_id` (impersonated account's
identity/preregistration) and `UserAccount.fetch_by_id` (Switch edu-ID). Adding
the stop event surfaced a latent policy ordering bug: the root catch-all sat
before the `:stop_impersonating` clause, so a root user who was not
impersonating passed authorization (a silent no-op before, a crash once the
event build required a non-nil impersonated account); the `:stop_impersonating`
clause was moved above the root catch-all so its `impersonated_id != nil` guard
applies to everyone.

### Accounts — schemas

`UserAccount`, `UserSession`, `LoginLink`, `PreregisteredUser`, `UserGroup`,
`SwitchEduId` identity. Split into two chunks if changesets are heavy. _Scope:_
6 schemas.

_Done:_ all six covered (`schemas/user_group_test.exs`,
`schemas/preregistered_user_test.exs`, `schemas/user_account_test.exs`,
`schemas/identity/switch_edu_id_test.exs`, `schemas/user_session_test.exs`,
`schemas/login_link_test.exs`), written in three reviewable chunks
(predicates/linking, account+identity, credentials). Unlike the course schemas
these have **thin changesets** but a **logic-dense pure/query surface**, so the
focus was the un-covered logic — date-window `active?/2` predicates, the
`SwitchEduId.create_or_update/2` upsert with its conditional touch, secure-token
generation (asserted at the schema level via `assert_secure_random_token`),
impersonation transitions, and name composition — while the thin query wrappers
stay covered by the session-lifecycle and auth use-case tests. Two new
`docs/testing.md` strategies the create/update/read/delete canon did not cover
were settled and documented: "Testing pure predicate functions over a date
window" (the boundary matrix and the `DateTime.to_date` in-memory-vs-query
granularity gotcha) and "Testing create-or-update (upsert) changesets" (the two
structural branches and the touch-only-when-changed assertion), plus a canon
note that **optimistic locking is observed through `changeset.filters`, not a
change** (the increment is applied only at `Repo.update` time). No latent bugs
were found: every accounts changeset already threaded the injected clock, so the
recurring clock gap the earlier spikes predicted did not recur here.

### Events context

Event store + core event operations (`use_cases`, `store`, errors). Small
context; one chunk. _Scope:_ ~8 files.

Done in `test/archidep/events/fetch_events_test.exs` (the read use cases
`fetch_events/2` and `fetch_event/2`) and `test/archidep/events/store/`
`stored_event_test.exs` (the store helpers `new/3`, `stream/4`,
`initiated_by/2`, `to_insert_data/1`, `to_reference/1`, `fetch_event/1`). The
context is read-only and owns the shared store, so the seven-point assertion
checklist collapses to exact return values plus absence of side effects, with
the store helpers covered as schema-style changeset tests. The protocols
(`Event`, `EventInitiator`) and `EventReference`/`EventHasNoIdentityError` carry
no logic of their own and are exercised through other contexts and the store
helpers, so they get no direct files.

The two patterns this context forces — composite `(occurred_at, id)` cursor
pagination and cross-context entity enrichment into the `entity` virtual field —
live as **comments in the test file**, not in
[`app/docs/testing.md`](../app/docs/testing.md): each exists in exactly one
place (`fetch_events/2`) and is not reused, so promoting it to general canon
would dilute the doc. _Follow-up:_ if a second use case ever adopts either
pattern, lift the shared rule into the testing guidelines at that point.

_Latent bug found and fixed:_ `FetchEvents.to_entity_ids_by_type/1` matched only
the known stream types with no catch-all, so any event with an unrecognised
stream crashed the whole read with a `FunctionClauseError`. A red test drove the
fix (a trailing catch-all that leaves such events with a `nil` entity).

_Stream coverage completed:_ audited every event stream the app can emit by
tracing the `add_to_stream/2` call sites — the only entities streamed are
classes, students, user accounts, preregistered users and servers (server groups
emit no events of their own). All five resolve. The one stream prefix declared
in the domain (the `SwitchEduId.event_stream/1` helper,
`accounts:switch-edu-id`) but not yet resolved was added to the resolver with a
matching test, so every declared stream now resolves to its entity; the
catch-all remains only for genuinely unknown/future streams.

_Follow-up — `StoredEvent.new/3` wall-clock default:_ its default `occurred_at`
calls `DateTime.utc_now/0` directly rather than the injected `ArchiDep.Clock`.
It is effectively dead today (every caller passes `occurred_at`), but it is a
clock-injection deviation that should be removed (make `occurred_at` required,
or thread the value in). The tests work around it by always passing
`occurred_at`.

### Servers — context use cases

The 8 `servers/use_cases` modules (server group/server CRUD orchestration). The
state machine is already heavily covered; this is the facade/use-case layer
around it. _Scope:_ 8 use cases, possibly split server-group vs. server. _Watch
for:_ `create_server/3` has the same masking-typo bug that was found and fixed
in `create_student/3` — its `with`/`else` authorizes `:create_server` but the
`else` clause matches `{:access_denied, :servers, :validate_server}`, so a
denied non-root caller hits a `WithClauseError` instead of the intended masked
`:server_group_not_found`. Fix the action atom and cover the denied path (see
the masked-errors guidance in [Authorization and
policy](../app/docs/testing.md#authorization-and-policy)).

_Done (part 1):_ the directly-testable slice landed — everything that does
**not** call into the server-tracking GenServers, in five files under
`test/archidep/servers/`: the two read modules (`read_server_groups_test.exs`
covering all six reads including `watch_server_ids`' subscribe/id-set/reducer,
and `read_servers_test.exs`), `create_server_test.exs` (the random/minimal/full
trio for both the root and group-member changesets, plus the validation,
uniqueness, limit and authorization-masking branches), and the
**database-mutating `%Server{}` arities** of update and delete
(`update_server_test.exs`, `delete_server_test.exs` — the update trio, the
active-server-count transitions, and the cascaded delete of the
expected-properties row). A `ServersTestHelpers` support module persists the
owner/group/member read-view graph (a class + a linked non-root student/account,
or a root account). Findings, all resolved: (1) the predicted **masking-typo
bug** was real and fixed — `create_server`'s `else` matched `{:access_denied,
:servers, :validate_server}` while `authorize` used `:create_server`, so a
denied non-root caller crashed with a `WithClauseError`; the denied path is now
covered. (2) The recurring **clock gap**: `Server.new`,
`new_group_member_server`, `update` and `update_group_member_server` stamped
`DateTime.utc_now()` themselves and `delete_server` did too, so timestamps were
unpinnable; all now take `now` from the use case's `Clock.now()`, matching the
course/accounts schemas. (3) The `ServersOrchestrator` subscribed to the
`servers:new` topic unconditionally, so a `server_created` broadcast woke it to
query the database outside any test's sandbox transaction and crash; it now only
subscribes when `track_on_boot` is set (a non-tracking node, e.g. the test
environment, stays inert). _Flagged for review:_ the owner server-count
assertions are kept **black-box** (the observable count change, not the full
`ServerOwner` row) pending the `ddd.md` reshaping of those columns. The
remaining tracking-coupled glue is split out below.

_Done — `ServerCreated`/`ServerUpdated` now carry the SSH host-key
fingerprints:_ mirroring the `ClassCreated`/`ClassUpdated` fix from the
class-use-case canon, `ssh_host_key_fingerprints` is now part of both server
events (added to each `@enforce_keys`/`defstruct`/`@type` and populated by
`new/1` from the `%Server{}`), so a `servers` row reconstructs from its event
alone. The `create_server`/`update_server` tests no longer supply the field by
hand: the persisted-row assertions read it back from the event data and the
event assertions assert it; the `server_manager` update-event test asserts it
too. The redacted secret key remains the only field the event omits.

### Servers — tracking-coupled use cases

The server use cases that delegate to the server-tracking GenServers, deferred
from the part-1 slice above: the **binary-id arities** of `update_server` /
`delete_server` (each fetches, authorizes, calls
`ServersOrchestrator.ensure_started/1`, then serializes the mutation through
`ServerManager`), `ManageServer` (`retry_connecting`, `retry_ansible_playbook`,
`retry_checking_open_ports`), and `ServerCallbacks.notify_server_up` (token
verification + event insert + a `ServerManager` cast).

_Done — the managers are mockable behind a Hammox boundary, not
`GenServerProxy`._ Rather than intercept the GenServers (which forces `async:
false` for the fixed-global `ServersOrchestrator` and validates no contracts),
the `ServerManager` client API and `ServersOrchestrator` are now reached through
thin injectable façades mirroring `ArchiDep.Http`/`ArchiDep.Clock`:
`ServerManagerClient` (backed by `ServerManagerClientBehaviour`, distinct from
the state-machine `ServerManagerBehaviour`) and `ServersOrchestratorClient`
(backed by `ServersOrchestratorBehaviour`). Each resolves to the real GenServer
via `Application.compile_env!` in `config/config.exs` and to a `*ClientMock` in
`config/test.exs`; the use cases call the façades, and the real GenServers
declare the new behaviours. Hammox contract-checks every expectation against the
behaviour's typespec, so the use-case ↔ manager boundary is validated and all
the glue tests run `async: true` (the mock dispatches to the calling process).
The DB-mutating halves of update/delete keep their part-1 `%Server{}` coverage;
the binary-id tests (folded into
`update_server_test.exs`/`delete_server_test.exs`) assert
fetch/authorize/`ensure_started`/delegate and the `:server_busy` / changeset
passthroughs, with no DB writes of their own (the manager is mocked).
`manage_server_test.exs` covers the three retries (happy path, the
`:server_not_connected` / `:server_busy` passthroughs, and the masked
not-found/unauthorized branches); `server_callbacks_test.exs` covers
`notify_server_up` with the full event/row/telemetry checklist plus the
expired/invalid/mismatched-token branches.

_Findings, all resolved:_ (1) `ManageServer`'s three functions and
`DeleteServer.delete_server/2` (binary) handled only the `access_denied` clause
in their `with`/`else`, so a malformed or unknown id — which surfaces as
`{:error, :server_not_found}` from `validate_uuid`/`fetch_server` — raised a
`WithClauseError` instead of returning the masked not-found (the
`:server_not_found` passthrough clause that `update_server/2` already had was
missing). (2) `ServerCallbacks.notify_server_up` passed the full
`%StoredEvent{}` to `ServerManager.notify_server_up/2`, whose contract is
`EventReference.t()`; it now converts with `StoredEvent.to_reference/1` (as
`update_server` already does), which Hammox now enforces. (3) The recurring
**clock gap**: `notify_server_up` stamped `DateTime.utc_now()`, so its
`ServerNotifiedUp` event's `occurred_at` was unpinnable; it now takes `now` from
the use case's `Clock.now()`.

### Servers — remaining schemas & Ansible pipeline (overview)

The untested servers schemas plus the testable core of the `servers/ansible`
pipeline, split into the seven reviewable chunks below. Two scope decisions
shape them:

1. **Schemas + `Tracker` logic only.** The runtime _process_ modules (the
   `Runner` subprocess, the GenStage pipeline, `ServerConnection`,
   `ServersOrchestrator`, `ServerTracker`) are split out into their own phase —
   see [6. Runtime processes](#canon--testing-runtime-processes) — because they
   need integration-style scaffolding rather than `DataCase` unit tests.
2. **Thread the injected clock.** The ansible/tracking schema builders currently
   call `DateTime.utc_now/0` directly (the recurring clock gap every prior chunk
   has fixed); make them take `now` and have the runtime callers pass
   `Clock.now/0`, per [Deterministic
   time](../app/docs/testing.md#deterministic-time-via-an-injectable-clock).

All chunks follow the settled canon: the random/minimal/full create strategy,
the update strategies, the `for variant <- […]` + `unquote` convention for rules
shared across changeset variants (as in `class_test.exs`/`student_test.exs`),
exact `errors_on(cs) == …` maps, and `count_rows/1` + `assert_row_count_diff/2`
on every DB-mutating path. Reuse `ServersFactory`, `SSHFactory` and
`ServersTestHelpers`. Expect the recurring clock gap and `with`/`else` masking
bugs to recur; fix and flag for review as established.

**Out of scope here** (deferred, not skipped): the runtime processes (phase 6);
`ServerOwner`'s count-mutation changesets (`update_active_server_count/2`,
`update_server_count/2`) and **every** `refresh!/2`, which the [DDD
plan](./ddd.md#sequencing-with-the-testing-plan) reshapes; `ServerGroup` /
`ServerGroupMember` (no changesets — queries are covered through the read
use-case tests); `Server`'s query functions (already covered by
`read_servers_test.exs`); and the `SSHKeyFingerprint` malformed-input case
(blocked on the parser-crash [known
issue](../app/docs/known-issues.md#ssh-host-key-fingerprint-parsing-crashes-on-malformed-input)).

### Servers — `Server` schema validations

Extend `schemas/server_test.exs` (today only the 4 reserved-username cases).
Cover all four builders — `new/4`, `new_group_member_server/3`, `update/3`,
`update_group_member_server/4` — exhaustively for every rule in `validate/1` and
the builder-specific validators: required fields; `name` length ≤50 and
uniqueness within the group; `username` / `app_username` length ≤32; the
`username == app_username` conflict; the reserved-username rule; `ssh_port`
numeric bounds; `ssh_host_key_fingerprints` parse validation; `ip_address`
uniqueness; and the active-server-limit / server-limit `validate_change`
branches on the group-member builders. Write rules shared across the
create/update variants once via `for variant <- […]` + `unquote`; keep divergent
rules (uniqueness self-exclusion on update, `validate_required` that cannot fail
on update) in per-variant blocks. This is the `Server` analogue of the
`class_test.exs` / `student_test.exs` backfill.

_Done:_ `schemas/server_test.exs` now covers all four builders exhaustively.
The shared `validate/1` value rules (name length/trim, `username` length,
`ssh_port` bounds, `ssh_host_key_fingerprints` parsing, error accumulation, and
a valid-data baseline) are written once and generated for all four builders via
`for variant <- [:new, :new_group_member, :update, :update_group_member]` +
`unquote`, dispatching through a private `changeset/2`. The divergent rules live
in their own blocks: `app_username` length and the `username == app_username`
conflict over the two root builders; the reserved-username rule over the two
group-member builders; required fields over the two create builders (plus the
root-only `app_username` requirement); DB-backed `name` / `ip_address`
uniqueness on `new/4` (no self-exclusion) and `update/3` (self-exclusion, plus a
keeps-its-own-value case); and the active-server-limit / server-limit
`validate_change` branches on the group-member builders. No latent bugs: these
builders already thread the injected `now` (the clock gap earlier chunks
predicted does not apply to `validate/1`), and there is no `with`/`else` masking
to misfire. One observation worth recording: unlike the course SHA256 field, the
server field parses fingerprints with the `:any` digest (`parse/1`), which
returns `{:error, :malformed}` cleanly, so a fully-malformed line could be
asserted directly rather than worked around — the
[parser-crash known issue](../app/docs/known-issues.md#ssh-host-key-fingerprint-parsing-crashes-on-malformed-input)
only affects the digest-specific `parse/2` paths.

### Servers — `Server` persistence functions & helpers

The three DB-mutating bang functions under `DataCase`: `mark_as_set_up!/2` (→
`ServerSetUp` event), `mark_open_ports_checked!/3` (→ `ServerOpenPortsChecked`),
and `update_last_known_properties!/3` (→ `ServerFactsGathered`, including the
no-change short-circuit that writes nothing). Assert the reloaded row, the
emitted event, and the `assert_row_count_diff` deltas (including `StoredEvent`).
**Thread `now`:** these three call `DateTime.utc_now/0` directly, as does
`find_active_server_for_group_member/1`; convert them to take `now` from the
runtime caller. Also cover the pure helpers not exercised elsewhere:
`active?/2`, `set_up?/1`, `changed?/3`, `valid_ssh_host_key_fingerprints/1`,
`default_hostname/1`, `name_or_default/1`, `ssh_connection_description/1`,
`event_stream/1`.

### Servers — `ServerProperties` schema

`detect_mismatches/2` is already covered. Add the changeset builders `new/3`,
`update/2`, `blank_changeset/1`, and the logic-dense
`update_from_ansible_facts/2` (fact-key mapping plus the invalid-field-nilifying
behaviour — assert an out-of-range fact is cleared, not rejected), with the
length limits and numeric bounds for every field generated via a `for` over the
field/limit list. (Note this is `Servers.Schemas.ServerProperties`, distinct
from the course `ExpectedServerProperties` already covered — it needs its own
tests.) Plus the pure helpers: `changed?/2`, `merge/2` (the `"*"` / `0` / `nil`
override semantics), `set_default_hostname/2`, `refresh/2`, `blank/1`.

_Done:_ `schemas/server_properties_test.exs` now covers all the changeset
builders and pure helpers. The shared `validate/1` rules (per-field string
length limits, per-field numeric bounds — here `0`-based, message `"must be
between 0 and {number}"`, unlike the course schema's `1`-based — trimming,
blank→nil, and error accumulation) are written once and generated for both
data-bearing builders via `for variant <- [:new, :update]` + `unquote`
dispatching through a private `changeset/2`; each builder's effect is pinned as
the **whole applied struct** (`Changeset.apply_changes/1` + one exact equality,
generated `id` bound from the result), per the settled canon. `new/3`'s
id-setting and `blank_changeset/1`'s validity get their own blocks, and the pure
helpers (`changed?/2`, `merge/2`'s `nil`/`"*"`/`0` override semantics,
`set_default_hostname/2`, `refresh/2`, `blank/1`) are asserted by whole-value
equality. The existing `detect_mismatches/2` tests were kept. **No clock gap
here** — `ServerProperties` has no `timestamps()` and no builder calls
`DateTime.utc_now/0`, so the overview's "thread the injected clock" step does
not apply to this schema.

_Latent bug found and fixed (flag for review):_ `update_from_ansible_facts/2`
called `cast` but **never `validate/1`**, so the length/numeric-bound rules
`new/3`/`update/2` enforce were not applied to ansible-gathered facts; and its
error-clearing block only `put_change`d the offending field to `nil` without
dropping the matching `changeset.errors` entry, so the changeset stayed `valid?:
false` — defeating its own stated goal ("save even in the presence of errors").
The net effect was the opposite of leniency: any abnormal fact **crashed** the
write. Confirmed end to end — a wrong-typed fact makes the nested changeset (and
thus the parent built by `change(server, last_known_properties: …)`) invalid, so
the `Multi.update` returns `{:error, …}` and the `{:ok, …}`-only `case` in
`update_last_known_properties!` raises a `CaseClauseError`; an over-255-char
hostname (Ecto `:string` → `varchar(255)`) takes the other route and overflows
the column on insert, crashing the same `case`. Both crash the per-server
tracking GenServer (`ServerManagerState.ansible_facts_gathered/2`), and gathered
facts come from an arbitrary student VM, so they are genuinely untrusted. Fixed
so the function realizes its intent: it now calls `validate/1` and then, for
every invalid field, **drops the change** (keeping the last known good value)
**and** the error, so the changeset stays valid and saves. Covered in
`server_properties_test.exs` (an over-range/over-length/wrong-typed fact is
cleared, `errors_on/1 == %{}`, valid facts map through; a now-invalid fact keeps
the previous value) and by a regression test in `server_test.exs`
(`update_last_known_properties!/4` no longer fails on an invalid fact — it
clears the field, stores the rest, and still records the raw facts in the
`ServerFactsGathered` audit event).

### Servers — `AnsiblePlaybookRun` schema

New `schemas/ansible_playbook_run_test.exs`. The state-transition builders
`new_pending/5`, `start_running/1`, `succeed/1`, `fail/2`, `interrupt/1`,
`time_out/1` (assert the resulting state / exit code / timestamps and the
`validate/1` rules: required fields, `playbook` / `user` length, `port` and
stats numeric bounds, state inclusion). The update-query builders
`touch_new_event/2` and `update_stats/2` run against a persisted row under
`DataCase`. The pure helpers `done?/1`, `duration/1`,
`ssh_connection_description/1`, `display_variables/1` (visible/hidden
classification), `stats/1`. **Thread `now`** into all six builders. **Flag for
review:** `validate_started_at_and_finished_at` compares with `Date.compare/2`
on `DateTime`s, so a same-day `finished_at` before `started_at` is not rejected
— likely should be `DateTime.compare/2`.

_Done:_ `schemas/ansible_playbook_run_test.exs` covers the six builders (each
asserted as the whole applied struct via `Changeset.apply_changes/1`, with the
`new_pending` shape pinned through a defaults-with-overrides helper), the two
update-queries against a persisted row (reloaded as the baseline so the INET
`/32` round-trip — `netmask: nil` built vs. `32` reloaded — does not spuriously
differ, with an all-zero `assert_row_count_diff`), and the pure helpers, all by
whole-value equality. The recurring **clock gap** was fixed as canon: all six
builders now take `now` and the three runtime callers (`ansible/tracker.ex`,
`ansible/pipeline/ansible_pipeline_queue.ex`,
`ansible/pipeline/ansible_pipeline_runner.ex`) pass `Clock.now()`.

Two bugs fixed (flag for review): (1) the predicted
`validate_started_at_and_finished_at` bug was real — `Date.compare/2` on two
`DateTime`s ignored the time of day, so a same-day out-of-order `finished_at`
was accepted; switched to `DateTime.compare/2` and pinned by a regression test.
(2) A copy-paste bug in the `ansible_playbook_event` factory popped `created_at`
with the `:occurred_at` key, leaving `created_at` unsettable; corrected to
`:created_at`.

_Decision (reachable-subset, human-approved):_ several `validate/1` rules cannot
be driven through the public builders — the `stats_*` columns are written only
by the non-validating `update_stats/2` query, `number_of_events` only by
`touch_new_event/2`, `exit_code` is guarded non-negative at `fail/3`'s head,
`state` is always a valid literal, the `port` comes from a `Server` already
constrained to `1..65_535` (or defaults to 22), and `assoc_constraint(:server)`
only fires at insert time. These defensive rules are left untested with a single
self-contained note in the test rather than forced through a hand-built
changeset back door.

### Servers — `AnsiblePlaybookEvent` schema

New `schemas/ansible_playbook_event_test.exs`. The `new/2` extraction builder:
each nested-path field present / missing / wrong-type (`binary_or`,
`utc_datetime_or_nil`), the 255-char truncation, `occurred_at` from `_timestamp`
vs. the now-fallback, and the `validate/1` length rules. Plus
`fetch_events_for_run/1` ordering under `DataCase`. **Thread `now`** into
`new/2`.

_Done:_ `schemas/ansible_playbook_event_test.exs` covers the extraction builder
(each `binary_or` / `boolean_or` / `utc_datetime_or_nil` fallback for a present
/ missing / wrong-type nested path, the `_timestamp` extraction vs. the
now-fallback including the non-zero-offset and bad-format rejections, the `trim`
/ `trim_to_nil` normalization, and the 255-char truncation) by
whole-applied-struct equality via a defaults-with-overrides helper, plus
`fetch_events_for_run/1` ordering under `DataCase` (full-list equality,
descending `occurred_at`, excluding another run's events). The recurring **clock
gap** was fixed as canon: `new/2` became `new/3` taking `now`, and the sole
runtime caller (`ansible/tracker.ex`) passes `Clock.now()`. _Reachable-subset
decision (human-approved):_ the `validate_length(max: 255)` rules cannot fire —
each field is truncated to 255 before the length check — and `run_id` / `data` /
`occurred_at` always receive a value through `new/3`, so those defensive rules
are left untested with a single self-contained note; only `name` can be made
blank (a whitespace-only `_event` trims to `""`), and that one reachable
`validate_required` branch is asserted.

### Servers — Ansible `Tracker` persistence & events

New `ansible/tracker_test.exs` under `DataCase`. `track_playbook!/6` (inserts
the pending run + `AnsiblePlaybookRunStarted`, returns the reference).
`track_playbook_event/4`: the `{:event, data}` path (insert event + touch the
run counters + the conditional `update_stats` only on `"v2_playbook_on_stats"` +
`AnsiblePlaybookEventOccurred`) and all three `{:exit, …}` branches — `{:status,
0}` → `succeed` + `AnsiblePlaybookRunFinished`, `{:status, code}` → `fail`,
`:epipe` → `fail(nil)`. Assert the persisted rows, the emitted domain events,
and the `assert_row_count_diff` deltas. This also covers the
`AnsiblePlaybookRunStarted` / `AnsiblePlaybookEventOccurred` /
`AnsiblePlaybookRunFinished` event structs end-to-end.

_Done:_ `ansible/tracker_test.exs` covers `track_playbook!/6` and every
`track_playbook_event/4` branch — the non-stats `{:event, …}` path (with the
`update_stats` no-op as the negative control), the stats `{:event, …}` path, and
the `{:status, 0}` / `{:status, code}` / `:epipe` exits — asserting the
persisted run and event rows, the three domain events (full `%StoredEvent{}`
equality, including the causation/correlation chain off the inbound references),
and the `assert_row_count_diff` deltas, all by whole-value equality. A
group-member owner graph pins the events' nested `server`/`group`/`owner` maps
to non-nil values. The Tracker already threaded `Clock.now/0` (the clock-gap
fixes landed with the `AnsiblePlaybookRun`/`AnsiblePlaybookEvent` schema
chunks), so no source change was needed; no latent bugs surfaced. One
reachable-subset note: the `{:exit, …}` branches ignore the `running_cause`
argument, so the tests reuse `started_cause` there rather than mint an unused
stored event.

### Servers — small schema leftovers

One PR (or attach to an adjacent chunk) for the tiny pure surfaces:
`ServerRealTimeState.busy?/1` (the matrix over connection states ×
`current_job`) and `problem?/2`; `AnsiblePlaybook.name/1` and `new/2`; and the
untested `SSHKeyFingerprint` parsers (`parse/1`, `parse/3`,
`fingerprint_human/1`, `key_algorithm/1` — `match?/2` is covered). **Triage
first** against the existing `ssh_test.exs` / `ssh_key_fingerprint_test.exs` to
avoid overlap, and leave the malformed-input case for the known-issue fix.

_Done:_ all three pure surfaces covered, with no DB/event/clock involvement so
they run under plain `ExUnit.Case` (matching the existing
`ssh_key_fingerprint_test.exs`). New `schemas/server_real_time_state_test.exs`
pins `busy?/1` across the full connection-state × current-job matrix (the six
states that are idle only when jobless, the same six busy once a job is set, and
the two states — `connecting` / `reconnecting` — that have no jobless clause and
are therefore always busy), generating the shared cases with a `for` over the
state list, plus `problem?/2` over its empty/nil/match/no-match/multi branches
using the `ServersFactory` problem builders. New
`schemas/ansible_playbook_test.exs` pins `new/2` (whole-struct) and `name/1`
(`Path.basename(_, ".yml")`, including a non-`.yml` extension left intact).
`ssh/ssh_key_fingerprint_test.exs` was extended (the six `match?/2` tests
untouched) with direct unit tests for `parse/1` and `parse/2` (the format
function is arity 2, not the `parse/3` the backlog text guessed): the MD5/SHA256
success structs, the wrong-length decode errors, `parse/1`'s graceful
`:malformed`, `:any` delegation (success + graceful malformed), and the
`:md5`/`:sha256` format-mismatch errors — plus `fingerprint_human/1` (both
digests, exact strings) and `key_algorithm/1`. _Reachable-subset decision:_ the
`parse/2` `:md5`/`:sha256` **fully-malformed** crash is left undriven (the
parser-crash [known
issue](../app/docs/known-issues.md#ssh-host-key-fingerprint-parsing-crashes-on-malformed-input)),
and `decode_key_fingerprint`'s `:unknown_fingerprint_format` branch is
unreachable through `parse` (the regex only ever yields an `MD5:`/`SHA256:`
prefix); both are recorded in a single self-contained comment. No latent bugs
and no clock gap surfaced — these are pure functions.

### Canon — web-layer LiveView test conventions

_Context:_ the web layer is tested with LiveCase/ConnCase + context Hammox mocks

- the foundations auth fixtures. Exemplar: `profile_live_test.exs`. This is the
  largest area by file count (77 web files) but the least logic-dense — mostly
  render/interaction/redirect assertions.

🧭 **The conventions note is drafted** — see the [Web layer
section](../app/docs/testing.md#web-layer-liveviews--controllers) of the testing
guide: the two-kinds-of-output split (exact-value outputs — title, flash, pushed
events, redirects, broadcasts, mock interactions, displayed data values — vs.
the DOM), the DOM-as-meaningful-projection philosophy (anchor on semantic
selectors; once a projection is chosen, assert it wholly; presence _and_
absence), the LiveViewTest-vs-`HtmlTestHelpers` tool split, the
mounting/auth/Hammox-mock conventions (including the disconnected+connected
double-mount call counts), forms (`render_change`/`render_submit`), and
flash/PubSub assertions.

The test HTML parser was also switched from Floki to **LazyHTML** (the engine
Phoenix LiveView 1.1 uses internally): `HtmlTestHelpers` is rewritten on
`LazyHTML`, the `floki` dependency is dropped from `mix.exs`, and
`profile_live_test.exs` is migrated — one HTML parser across the suite. One real
divergence surfaced and is handled: `LazyHTML.query("title")` also matches
SVG-icon `<title>` nodes in the body and `LazyHTML.text/1` concatenates them, so
`assert_html_title` scopes its query to `head > title`.

The remaining spike work — and **the next task to pick up** — is to bring the
chosen worked example, the **profile page**, up to this drafted canon and get it
reviewed. `profile_live_test.exs` today covers the page title and the sessions
table well (the "all sessions" test is the model to follow) but falls short of
the bar in six ways the new conventions name; close them, refactor, and agree:

1. **The `data_display` section is entirely untested.** Assert the six rows in
   `profile_live.html.heex` — account username, email, Switch edu-ID name,
   confirmed username + Change button, Swiss edu person unique ID (root-only),
   registration date — each behind an `:if`. Pin the displayed value _and_ the
   presence/absence per branch (the Swiss-edu-ID row shows only for root; the
   Change button only when `username_confirmed`).
2. **The student tests assert nothing student-specific.** The `as a student`
   block re-tests the sessions table but never the email row, the username row,
   or the Change-username button only the student path renders. Assert the
   student-only projection.
3. **`ChangeUsernameDialogLive` is untested.** Cover the `validate` event (live
   changeset validation renders / clears the error) and the `configure` event —
   success (the `"Username changed to {name}"` notification, the
   `push_event("execute-action", close)`, the reset form) and failure (changeset
   re-render).
4. **The `student_updated` PubSub handler is untested.** Broadcast
   `{:student_updated, …}` on the subscribed per-student topic and assert the
   re-rendered username reflects the update.
5. **The delete-session _success_ notification is unasserted.** The happy path
   asserts only that the row disappears; assert the `"Deleted session"` success
   flash too (the not-found path already asserts its warning), so the success
   path is no less thorough than the error path.
6. **Tighten the partial table assertions and small gaps.** Most per-row matches
   wildcard the cells the test claims to care about (`_login`, `_exp`, `_ip`,
   `_client`); bring them to the projection discipline (project out what is
   irrelevant; pin what matters). Also cover the `expires_soon?` highlighting
   and make the flash-message expectations consistent (`gettext` vs. hardcoded
   English).

Output: the signed-off conventions note (above) + the brought-up-to-canon
profile tests as the reviewed example. `server_live.ex` + its three dialogs then
become an ordinary follow-up second example under [Servers web — server detail &
dialogs (remainder)](#servers-web--server-detail--dialogs-remainder), no longer
the canon blocker.

### Servers web — server detail & dialogs (remainder)

Finish `server_live` + `new`/`edit`/`delete_server_dialog_live` not done in the
canon task.

_Blocked (needs a seam first):_ `server_live.mount/3` calls the `ServerTracker`
runtime GenServer **directly** — `ServerTracker.start_link/1` and
`ServerTracker.get_current_server_state/1`, the latter _outside_ the
`connected?(socket)` guard, so even a disconnected `get/2` render needs a live
tracker. `ArchiDep.Servers.ServerTracking.ServerTracker` is not in the
`config/test.exs` mock swap and has no injectable seam, so the page cannot be
web-tested today. **Prerequisite:** introduce a `ServerTrackerClient` façade +
`ServerTrackerClientBehaviour` mirroring `ServerManagerClient` /
`ServersOrchestratorClient` (`@implementation
Application.compile_env!(:archidep, __MODULE__)`, `defdelegate`s for
`start_link` / `get_current_server_state` / watch), wired to the real tracker in
`config/config.exs` and to a `ServerTrackerClientMock` in `config/test.exs`;
`server_live` then calls the client. This belongs with [6. Runtime
processes](#canon--testing-runtime-processes) (the `ServerTracker` chunk). Until
it lands, the servers-web LiveView chunks are blocked.

_Re-sequencing:_ because of this blocker, the **second web-layer exemplar** is
the admin classes list + create-class dialog (see [Admin — classes list/detail +
class dialogs](#admin--classes-listdetail--class-dialogs)), which is driven
purely by the Hammox-mocked `Course` context with no runtime coupling.
`server_live` + its dialogs follow once the `ServerTrackerClient` seam exists.

_Done — the seam is introduced as phase-2 work and the page is covered._ The
`ServerTrackerClient` façade + `ServerTrackerClientBehaviour` now mirror
`ServerManagerClient` / `ServersOrchestratorClient` exactly (`@implementation
Application.compile_env!`, `defdelegate`s for the full tracker client surface:
`start_link` / `track` / `untrack` / `server_state_map` /
`update_server_state_map` / `get_current_server_state`), wired to the real
`ServerTracker` in `config/config.exs` and to a `ServerTrackerClientMock` in
`config/test.exs`, with the GenServer now declaring the client behaviour. Only
`server_live` is migrated to the client in this chunk (the other tracker
consumers — `admin_live` / `my_servers_live` / `dashboard_live` — adopt it with
their own test chunks, which each carry additional gaps; the behaviour already
covers their surface so no behaviour change is needed). `server_live_test.exs`
covers the detail page through both the `/admin/servers/:id` (root) and
`/servers/:id` (owner) routes — the whole data-display projection per principal
(group/owner rows and the delete dialog are root-only), the not-found redirect,
the edit dialog (validate wiring; a full and a clear-every-optional update each
pinning the exact submitted data map; the update-failure error + flash), the
delete dialog, the `{:server_updated}` / `{:server_deleted}` / `{:server_state}`
live updates, and the three retry-event delegations. The tracker client and
`fetch_server` are stubbed (they fire across the disconnected+connected mounts);
each mutation is `expect`ed once.

_Scope note:_ `new_server_dialog_live` is **not** hosted on `server_live` (it
lives on `dashboard_live` / `my_servers_live`); per the "components are tested
through their host page" canon it moves to the [Dashboard](#dashboard) chunk.

_The `server_components` clock gap is fixed (flag for review):_ its two retry
countdown helpers called `DateTime.utc_now/0` directly; they now read the
injectable `ArchiDep.Clock`, matching `current_sessions_live` and the
clock-injection canon, so the page renders deterministically under the
`Clock.Mock`.

_Two latent type bugs found and fixed (flag for review):_ (1)
`ServerForm.to_update_data/1` put a `:group_id` key into the data map even
though `Types.server_data()` has no such key (and `to_create_data/1` already
dropped it) — the real context silently ignored the extra key, but Hammox
rejects it; it now `Map.delete`s `:group_id` like its create sibling (the
`server_form_test.exs` expectation was updated to match). (2)
`Types.server_properties` declared all 13 keys `required`, but the form's
`expected_properties` map legitimately omits the non-editable
`hostname`/`machine_id` (and casts a subset) — the same partial-map type bug
fixed earlier on `Course.Types.expected_server_properties`; the keys are now
`optional(...)`, the accurate model (behaviour-preserving for the full-map
ansible callers). _Coverage ratchet:_ with the suite at 67.8%,
`coveralls.json`'s `minimum_coverage` was bumped 61 → 66.

_Follow-up unblocked:_ `classes_controller` and `student_live` are still blocked
by a **separate** seam — they call the schema query
`Server.find_active_server_for_group_member/2` directly (plus
`DateTime.utc_now`) rather than a mocked context facade; route that through
`ArchiDep.Servers` (and the injected clock) in a later chunk to unblock them.

### Servers web — forms & components

`server_form`, `server_form_component`, `server_properties_form`,
`server_components`, `server_help_component`. _Scope:_ 5 files.

_Done (part 1) — the two embedded form schemas:_ `server_form_test.exs` and
`server_properties_form_test.exs` cover `ServerForm` and `ServerPropertiesForm`
exhaustively under `DataCase` (pure embedded changesets — no rows written), the
direct analogue of the [class form components](#admin--class-form-components)
and [student form components](#admin--student-form-components) siblings. Both
source files are at 100%. `ServerForm` follows the settled canon: the shared
cast/value rules (invalid `ssh_port`, invalid `active`, the nested
`expected_properties` error, accumulation) are written once and generated for
both `create_changeset/2` and `update_changeset/2` via `for variant <- [:create,
:update]` + `unquote` dispatching through a private `changeset/2`; the
**auth-conditional required fields** are the one novel branch (`group_id` is
required only for a root caller, asserted by the whole `errors_on` map for a
non-root vs. root auth); and each builder's effect is pinned as the **whole
applied struct** via `Changeset.apply_changes/1` (create minimal/full, update
update-everything/ clear-every-optional, with the seeded `group_id` retained
since it is not in the update cast list, and the seeded `expected_properties`
reconstructed through `ServerPropertiesForm.from/1`). `to_create_data/1` (group
dropped, the nil → `%{}` branch), `to_update_data/1` (group retained), and
`blank_changeset/0` are pinned by whole-value equality. `ServerPropertiesForm`
covers `changeset/2` (cast + the invalid-integer branch), both `from/1`
overloads (from an `ExpectedServerProperties` and a `ServerProperties`, the only
place each is exercised), and `to_data/1`. No latent bugs or clock gap surfaced
— these form schemas have no `timestamps()` and no `DateTime.utc_now/0` call.

_Remaining (box left open):_ the three presentational components.
`server_form_component` is a pure presentational function component (no logic),
deferred-to-page per the "Components: Through the Page or In Isolation" canon —
it lands with the servers-web pages once the `ServerTrackerClient` seam exists
(see [Servers web — server detail & dialogs
(remainder)](#servers-web--server-detail--dialogs-remainder)). `server_components`
and `server_help_component` carry real logic (problem classification, status/badge
text, state predicates) but are likewise rendered only through the
seam-blocked servers-web pages, and `server_components` additionally has a direct
`DateTime.utc_now/0` call (a wall-clock gap to fix when it is covered); both stay
deferred until the seam lands. _Coverage ratchet:_ with the suite at 61.9%,
`coveralls.json`'s `minimum_coverage` was bumped 60 → 61.

_Box closed:_ the three presentational components are now covered as the seam
landed in later chunks — `server_components` and `server_help_component` have
dedicated isolation tests (both at 100%, the `server_components` clock gap fixed)
and `server_form_component` is page-covered through the dashboard / my-servers
dialogs per the "components through the page" canon. See [Dashboard](#dashboard).

### Servers web — controllers & retry handlers

`server_callbacks_controller` (ConnCase request tests), `server_retry_handlers`.
_Scope:_ 2 files.

_Done:_ both covered (`servers/server_callbacks_controller_test.exs`,
`servers/server_retry_handlers_test.exs`), each at 100%. The controller test is
the suite's first non-trivial **controller request test** (beyond the minimal
`page_controller_test.exs`): it drives the public `POST
/api/callbacks/servers/:server_id/up` webhook with verified routes, asserting
the response status **and** the empty body, and pinning the
`Servers.notify_server_up` mock interaction by `==` — including the bearer-token
branches (missing / malformed / multiple `authorization` headers), where setting
**no** mock expectation makes `verify_on_exit!` prove the notification is never
attempted. The retry-handler test exercises the three handlers as isolated
socket transformers: it builds a minimal `%Phoenix.LiveView.Socket{}` with
`auth` + an empty `flash` and asserts the **whole** returned socket by equality
— the flash through the existing `LiveCase.flash_notifications/1` projection and
everything else (other assigns, `redirected`, pushed events) compared directly,
with only the framework's flash bookkeeping (`assigns.__changed__` and
`private.live_temp[:flash]`) normalized away — so a stray assign, redirect or
push would fail the test. Each mocked context call is pinned by `==`. The
controller request-test shape is kept as a single in-file comment (one
consumer); promote to the controller subsection of `docs/testing.md` when a
second controller chunk (`classes_controller`, the auth controller) reuses it.
_Latent bug found and fixed (flag for review):_ none of the three retry handlers
handled the `{:error, :server_not_found}` their context functions declare —
`handle_retry_connecting_event` did a bare `:ok = …` match (crashing with a
`MatchError`) and the ansible / open-ports `case` blocks omitted the clause
(crashing with a `CaseClauseError`); since the `server_id` comes from a rendered
page, a server deleted between render and the retry click crashed the live view.
All three now handle it consistently with a graceful error notification ("Cannot
retry because the server no longer exists."), each covered by a test. No clock
gap (these handlers stamp no time). _Coverage ratchet:_ with the suite at 61.4%,
`coveralls.json`'s `minimum_coverage` was bumped 58 → 60.

### Admin — classes list/detail + class dialogs

`classes_live`, `class_live`, `classes_controller`,
`new`/`edit`/`delete_class_dialog_live`,
`edit_class_expected_server_properties_dialog_live`, `admin_class_servers_live`.
_Scope:_ ~8 files.

_In progress — this is the **second web-layer exemplar**_ (the canon task's
`server_live` example is
[blocked](#servers-web--server-detail--dialogs-remainder) on the `ServerTracker`
seam). `classes_live` + `new_class_dialog_live` (with `class_form`) have landed
in `classes_live_test.exs`, settling three conventions the profile page didn't
exercise, now documented in
[`docs/testing.md`](../app/docs/testing.md#web-layer-liveviews--controllers): a
**list/table page with PubSub mutations** (full-list assertion at mount, but
per-row-by-id assertions after a broadcast on the shared, non-keyed `"classes"`
topic, which is not async-isolated), a **multi-field/nested-embed form** (wiring
only — validate/submit + adding an embedded SSH-key sub-field; exhaustive rules
stay in the form-schema test), and an **authorization-delegated (admin) page**
(no web-layer root guard, so the both-principals rule resolves to root +
anonymous at the web layer). Two latent bugs in `new_class_dialog_live.ex` were
fixed and flagged: the `validate` handler ran validation twice (a discarded
`validate_dialog_form/4` call left beside a manual reimplementation —
`Course.validate_class` was called twice per keystroke; removed the dead call),
and the `create` failure branch built `changeset.errors ++ result_changeset`
(list `++` struct) and lacked an action, so a rejected create crashed instead of
rendering the error (now `++ result_changeset.errors` with `action: :insert`).
`class_live` (the detail page) + `edit_class_dialog_live` +
`delete_class_dialog_live` have since landed in `class_live_test.exs`. The
detail page is the most coupled admin page so far — its `mount/3` reads **two**
contexts (`Course.fetch_class` +
`Servers.fetch_server_group`/`watch_server_ids`, both Hammox-mocked;
`watch_server_ids` is pure, so no `ServerTracker` coupling) and subscribes to
four per-resource topics. The edit/delete dialogs are `live_component`s hosted
**only** here (the list page navigates to the detail page), so they are tested
through it. This settled one new convention now in
[`docs/testing.md`](../app/docs/testing.md#web-layer-liveviews--controllers):
**deep pages stub their ambient context reads and `expect` only the action under
test** (the detail page lists students three times per render — its own load
plus the delete and import dialogs — and a child notification re-renders the
parent, re-firing every child's `update/2`, so exact counts are brittle); plus a
small **update-form** addition (a full and a clear-every-optional submission,
both pinning the exact submitted data map). The per-resource-topic case (assert
the whole re-render, vs. the list page's global-topic per-row assertions) was
already documented. One latent bug was fixed and flagged:
`edit_class_dialog_live.ex`'s `update`-failure branch set no form `action`, so a
rejected update rendered no errors (added `action: :update`, the update analogue
of the new-class `action: :insert` fix).
`edit_class_expected_server_properties_dialog_live` (the third and last dialog
hosted on the detail page) has since landed in the same `class_live_test.exs`,
reusing the existing `build_class_and_group`/ `stub_class_page` infrastructure:
validate wiring, a full and a clear-every-optional update (both pinning the
exact submitted data map), the update-failure error rendering + `"The form is
invalid."` flash, and the page-level **Edit** (set) vs **Define** (blank)
trigger branch. No `action:` fix was needed here: unlike the edit-class dialog
(which renders its own action-less form changeset with merged errors), this
dialog renders the context's changeset directly, and that changeset already
carries both the cast params and an action, so its errors render. One latent
**type** bug was fixed and flagged: `Course.Types.expected_server_properties`
declared all 13 keys `required`, but the dialog legitimately passes a
**partial** map (it omits `hostname`/`machine_id`, which it cannot edit, so
`ExpectedServerProperties.update`'s `cast` preserves them) — Hammox enforced the
over-strict type and rejected the call. The type now uses `optional(...)` keys,
which is the accurate model (every caller casts a subset; behaviour-preserving
for the full-map callers). _Helper reuse evaluated:_ the only genuinely shared
helper is errors-within-a-form-by-id, already parameterized in
`class_live_test.exs` and renamed `class_form_errors/2` → `form_errors/2`; no
shared support module was created — `classes_live_test.exs`'s value readers
(`form_values`, input/textarea/checkbox) are single-consumer and hardcoded to
the new-class form, and the expected-properties tests capture submitted data
through the mock rather than the DOM, so they need no readers. Revisit
extraction when a third consumer (the `class_form_component` test) needs the
value readers. `admin_class_servers_live` is covered through `admin_live` (see
[Admin — top-level shell](#admin--top-level-shell)) — a pure presentational child
`live_component` with no route of its own, per the components-through-the-page
canon.

_Done:_ the box's last file, `classes_controller`, landed in
`classes_controller_test.exs` as the first **download-response** controller test
(the only prior controller test asserts status-only JSON). Each request is
asserted as one whole-response projection by `==` — `%{status, content_type,
content_disposition, body}` — with the CSV `body` pinned as the exact string
(comma-free fixture values, so no escaping; the `nil`-server row's empty ip/
username cells and the `academic_class || ""` fallback are exercised) and the
JSON inventory `body` decoded (`Jason.decode!`) and pinned by `==`; the `401`
paths assert `response(conn, 401) == "Unauthorized"` with `verify_on_exit!`
proving the downstream context/seam are never called. Per the admin-page canon
(no web-layer root guard) the principals are root (success + empty-class) and
anonymous (→ 401); the redundant "logged-in-but-unauthorized" case collapses
into anonymous, since both manifest at the web layer only as `fetch_class`
returning an error.

The controller needed the same seam adoption + clock fix prior chunks applied
(flag for review): `find_active_server_data_for/1` called the raw schema query
`Server.find_active_server_for_group_member(id, DateTime.utc_now())` directly —
a wall-clock gap, a seam bypass (no authorization), and unmockable. It now
threads `auth` and calls the existing read façade
`Servers.fetch_active_server_for_group_member/2` (which authorizes root and
reads `Clock.now()`), exactly as `student_live` already does. Driving the
anonymous path surfaced one latent **type** bug (flag for review): the
`Course.fetch_class` behaviour callback typed `auth` as `Authentication.t()`,
but the whole `nil`-auth path is intended (`authorize/5` guards
`is_authentication(auth) or is_nil(auth)`, the policy catch-all denies `nil`,
`fetch_class` masks the denial, and the controller returns 401) — Hammox
rejected the legitimate `nil` call. The callback and the
`ReadClasses.fetch_class` impl `@spec` now type `auth` as `Authentication.t() |
nil` (the delegated `Course.fetch_class` spec follows automatically).
`class_live` needed no further work: its template renders no server table (only
the class's expected-server-properties, already tested, and a `servers_count`
feeding the delete-dialog block, already tested via a `server_created`
broadcast); its student table + student/server PubSub handlers landed with the
Admin — students chunk; and `class_form_test.exs` covers the `ClassForm`
sibling.

### Admin — class form components

`class_form`, `class_form_component`, `class_form_ssh_public_key`. _Scope:_ 3
files.

_Done:_ the two form-layer embedded schemas the [Admin — classes dialog
tests](#admin--classes-listdetail--class-dialogs) deferred to are now covered
exhaustively, under `DataCase` (for `errors_on/1` + the `CourseFactory`; no rows
are written — these are pure embedded changesets). `class_form_test.exs` runs
the shared cast/value rules (required `name`, invalid date casting, the nested
blank-teacher-key error, accumulation) once over both `create_changeset/1` and
`update_changeset/2` via the settled `for variant <- [:create, :update]` +
`unquote` convention, plus per-variant blocks asserting the **whole applied
struct** by equality: create minimal/full and update update-everything/
clear-every-optional (the full/update cases double as the `tmp_boolify`
boolean-coercion proof, so no partial single-field assertion is needed). It also
pins `to_class_data/1` (full map, the single-blank-key → `[]` collapse, empty
list) and `add_teacher_ssh_public_key/1` (append from a non-empty and an empty
form), all by whole-value equality. `class_form_ssh_public_key_test.exs` covers
`new/1` and `changeset/2` (trim, required, whitespace-only → blank). No latent
bugs or clock gap surfaced — these schemas have no `timestamps()` and no
`DateTime.utc_now/0` call. _Component decision:_ `class_form_component` is a
pure presentational function component embedded only in the new- and edit-class
dialogs, whose rendered values and errors are already asserted through
`classes_live_test.exs` / `class_live_test.exs`; per the "Components: Through
the Page or In Isolation" canon it carries no logic and gets no isolated test.

### Admin — students list + student dialogs

`student_live`, `new`/`edit`/`delete_student_dialog_live`,
`import_students_dialog_live`. _Scope:_ 5 files.

_Done:_ the chunk required first unblocking the seam that prevented these pages
from being web-tested: `student_live` (and `classes_controller`) called the
schema query `Server.find_active_server_for_group_member/2` **directly** and
read wall-clock time. A mockable read facade
`Servers.fetch_active_server_for_group_member/2` was introduced (behaviour
callback + `ReadServers` impl authorizing root via the existing policy
catch-all, threading `Clock.now()`, masking both `:server_not_found` and the
`{:multiple_servers_found, _}` schema returns; wired in `context.ex` and
delegated in `servers.ex`), covered by `read_servers_test.exs`. Dialyzer
surfaced a latent spec bug while validating the new masking clause:
`Server.find_active_server_for_group_member/2`'s typespec omitted its real
`{:error, {:multiple_servers_found, _}}` return (the implementation has always
produced it); the spec was corrected (flag for review). `student_live` now
reaches the schema only through that mocked facade and reads the injected
`Clock` (its six `DateTime.utc_now/0` calls removed). `classes_controller`
shares this blocker and can adopt the same facade in the _Admin — classes
(remainder)_ chunk — left out here to keep the chunk reviewable.

`student_live_test.exs` covers the student detail page through both principals'
shared admin route: the whole data-display projection (registered vs.
unregistered, active server vs. none, the servers-enabled override note), the
not-found redirect, the generate-login-link success/not-found paths, the edit
dialog (validate wiring; full and clear-`academic_class` updates pinning the
exact submitted data map; update-failure error render) and delete dialog through
the page, and the live PubSub handlers (`:student_updated`, `:student_deleted`,
`:class_updated`, `:class_deleted`, `:server_created`/`:server_updated`/
`:server_deleted`), each asserting the whole page projection by `==`. The
deferred `class_live` student table + new-student dialog + student/server PubSub
handlers landed in `class_live_test.exs` (table rows + registered count + empty
state; new-student validate/minimal/full/failure; the student/imported/
preregistered-user reload handlers via an Agent-backed `list_students` stub; the
server-tracking handler driven through a real group-topic broadcast affecting
the delete-dialog block). `ImportStudentsDialogLive` is covered through the page
by pre-writing the CSV it parses on mount (column detection, new/existing
classification, a validate rejection, and the import action pinning the
`Course.import_students` data map) — the live file-upload event itself
(`consume_uploaded_students`) stays uncovered.

_Reachable-subset / deferred coverage:_ `student_live`'s
`:preregistered_user_updated` handler calls `Student.fetch_student/1` (the DB)
directly rather than through the mocked context, so it is not web-testable
without a further seam (flagged for review, like the `find_active_server` seam);
the in-memory `%Server{}`-refresh branches of
`maybe_refresh_server_group`/`maybe_refresh_server_group_member` (reached only
when an active server with a matching group member is already loaded) and the
facade's `{:multiple_servers_found, _}` masking are left as defensive paths.
_Coverage ratchet:_ with the suite at 78.4%, `coveralls.json`'s
`minimum_coverage` was bumped 74 → 76.

### Admin — student form components

`student_form`, `student_form_component`, `import_students_form`. _Scope:_ 3
files.

_Done:_ the two form-layer embedded schemas are now covered exhaustively under
`DataCase` (for `errors_on/1` + the `CourseFactory`; no rows are written — these
are pure embedded changesets), mirroring the [class form
components](#admin--class-form-components) sibling. `student_form_test.exs` runs
the shared value rules (the six `validate_not_nil` fields rejected when nil —
message `"cannot be nil"`, not `"can't be blank"` — and an invalid boolean) once
over both `create_changeset/1` and `update_changeset/2` via the settled `for
variant <- [:create, :update]` + `unquote` convention, plus per-variant blocks
asserting the **whole applied struct** by equality: create minimal/full and
update update-everything/clear-`academic_class` (the lone nilable field; the
remaining string fields cannot be blanked without tripping `validate_not_nil`,
and booleans coerce natively without `ClassForm`'s `tmp_boolify`). It also pins
`to_student_data/1` by whole-map equality (with and without an academic class).
`import_students_form_test.exs` covers the logic-dense `changeset/2 (params,
students)`: the required-fields map, both `name_column` rejections (all-emails
and the < 90%-unique pluralized message — `gettext` resolves the ICU
`{count}`/plural at call time, so `errors_on/1` receives the final string), both
`email_column` rejections (no-email, duplicates), the `academic_class`/`domain`
length limits, the domain format message, and a valid-mapping baseline — each by
whole `errors_on/1 == %{...}` equality. No latent bugs or clock gap surfaced —
these schemas have no `timestamps()` and no `DateTime.utc_now/0` call.
_Component decision:_ `student_form_component` is a pure presentational function
component (7 scalar inputs, no logic) embedded only in the new- and edit-student
dialogs; per the "Components: Through the Page or In Isolation" canon it gets no
isolated test and will be exercised through the page when the [Admin — students
list + student dialogs](#admin--students-list--student-dialogs) chunk lands.
Unlike `class_form_component` (already page-covered), it is **not yet** covered
today — that chunk is blocked on a `Servers` seam (`student_live` calls
`Server.find_active_server_for_group_member/2` directly rather than through a
Hammox-mocked context facade, and stamps wall-clock time), so its lines land
with the dialog chunk once the seam exists. _Coverage ratchet:_ with the suite
at 59.4%, `coveralls.json`'s `minimum_coverage` was bumped 35 → 55 (a safety
margin below the measured value for fixture-randomness variance); the final 90%
target stays deferred to [Lock the global
threshold](#lock-the-global-threshold).

### Admin — events views

`event_live`, `event_log_live`, `events_components`. _Scope:_ 3 files.

_Done:_ all three covered, the first unblocked admin chunk after the classes
work (the servers/students/ansible/dashboard pages are blocked on a
`ServerTracker`/`Tracker`/wall-clock seam; the events pages read only the
fully-mocked `Events` context). `events_components_test.exs` covers the three
presentational helpers (`event_context`/`event_action`/`event_entity`) **in
isolation** with `render_component/2` — they are reused across both event pages
and classify by `StoredEvent.type`/`.entity`, so each documented branch is
pinned by a `{text, sorted-class-tokens}` (or `{text, wrapper-class-tokens}`)
whole-value projection; the fallback's literal `class="badge badge"` is asserted
faithfully rather than deduplicated. `event_log_live_test.exs` settles a
**cursor-paginated list page**: every test asserts one whole-page projection
(`%{rows, pagination}` — the table plus the first/previous/next control
visibility and the end-of-timeline message), and the `fetch_events` cursor for
each request is pinned **exactly in the mock matcher** (`[limit: 50]` at
first/reset, `[limit: 50, older_than: {id, occurred_at}]` on next, `newer_than`
on previous), so a wrong request fails the call rather than going unobserved. A
full page is built from interchangeable events (the rendered table is the same
row repeated `@limit` times, the per-page timestamp telling one full page from
the next across a navigation), which keeps the whole-table assertion exact
without hand-listing 50 rows. `event_live_test.exs` covers the detail page with
a single whole-page projection too (`%{data_display, data, metadata}`): the
`data_display` rows whole — context/cause cells projected as their badge-label
lists since adjacent badges render with no separating text, and each cause cell
additionally carrying its link target — plus the `Jason`-pretty data/metadata
panels. It also pins the `Task.await_many` immediate/root-cause fetches, the
self-cause skip (an exact two-call `fetch_event` count, proving the related
fetches are elided), and the not-found redirect to `/admin/events`.

No latent bugs or clock gaps surfaced (these are read-only pages over a mocked
context). The cursor-pagination conventions were left as in-file comments rather
than promoted to `docs/testing.md`: the pattern lives in exactly one page today,
so per the existing meta-rule (lift a pattern into the canon only when a second
consumer adopts it) it stays local until a second paginated page lands. One
reachable-subset decision: `paginate_events`'s `{:next, nil, nil}` clause is
unreachable through the UI (an empty first page sets `end_of_timeline?`, hiding
the next control), so it is left uncovered as a defensive guard. _Coverage
ratchet:_ with the suite at 60.9%, `coveralls.json`'s `minimum_coverage` was
bumped 55 → 58.

### Admin — ansible views

`ansible_live`, `ansible_playbook_run_live`, `ansible_components`. _Scope:_ 3
files.

_Done:_ all three covered. `ansible_components_test.exs` unit-tests the three
presentational helpers in isolation with `render_component/2`
(`ansible_playbook_run_state` per state, `ansible_playbook_run_stats` /
`ansible_stat` per stat by a `{label, sorted-class-tokens}` whole-value
projection, exhausting every state and stat-color branch).
`ansible_playbook_run_live_test.exs` (the detail page) and
`ansible_live_test.exs` (the list page) each assert a single whole-page
projection by `==`: the detail page projects the data-display rows (the Playbook
cell whole, including its nested tooltip text; the Server cell as `{name,
link}`), the variables table (`{key, :visible|:hidden, value}`), and the async
events table; the list page projects each run row (`{playbook, start, duration,
state, events, tasks}`) and exercises the tracker-presence overlay plus the
`:join` / `:update` / `:leave` diff handlers (including chronological insertion
of a joining run) via real messages, asserting the converged page each time.

This chunk required first introducing the **`TrackerClient` seam**:
`ansible_live` read the ansible-queue presence list by calling the
`ArchiDep.Tracker` `Phoenix.Tracker` GenServer directly
(`Tracker.list("ansible-queue")`), which is not mockable. A thin
`ArchiDep.TrackerClient` façade + `ArchiDep.TrackerClientBehaviour` (just
`list/1`) now mirror `ServerTrackerClient` (`@implementation
Application.compile_env!`, wired to `ArchiDep.Tracker` in `config/config.exs`
and to `ArchiDep.TrackerClientMock` in `config/test.exs`, with the tracker
declaring the behaviour); only `ansible_live` is migrated to the client this
chunk (`admin_live`, which also calls `Tracker.list`, adopts it with its own
chunk, as `server_live` did for `ServerTrackerClient`). The recurring **clock
gap** was fixed (flag for review): both LiveViews read `DateTime.utc_now/0`
directly and now use `ArchiDep.Clock.now()`. `ansible_live` also reached the
schema query `AnsiblePlaybookRun.fetch_run/1` directly; it now uses the existing
mocked `Servers.fetch_ansible_playbook_run/2` facade.

Four latent bugs were found and fixed (flag for review): (1) the detail page's
`mount/3` piped `fetch_ansible_playbook_run` straight through `unpair_ok`, so a
not-found run (e.g. deleted between the list render and navigation) **crashed**
instead of redirecting; it now redirects to `/admin/ansible` with an error
flash, matching the event detail page. (2) The
`fetch_ansible_playbook_events_for_run` callback (and the use-case `@spec`)
declared `{:ok, list(AnsiblePlaybookRun.t())}` but the implementation returns
`AnsiblePlaybookEvent.t()` — a copy-paste from the run callback; corrected,
which Hammox now enforces. (3) `AnsiblePlaybookEvent`'s `run` association type
used the bare module `NotLoaded` instead of `NotLoaded.t()`, so Hammox treated
it as an atom literal and a real unloaded `run` (the production shape —
`fetch_events_for_run` does not preload it) failed the contract; fixed to
`NotLoaded.t()` like every other schema. (4) `AnsiblePlaybookEvent`'s `data`
type was `%{String.t() => term()}` (a **required** key), so an event with empty
`data` failed the contract — the same `required` → `optional` map-type fix made
earlier on `Types.server_properties` / `ServerTrackerClientBehaviour`; now
`%{optional(String.t()) => term()}`. (_The same bare-`NotLoaded` appears on
`AnsiblePlaybookRun.server`, but that read always preloads the server, so it is
left untouched and the test builds runs with a loaded server.)_ _Coverage
ratchet:_ with the suite at 80.0%, `coveralls.json`'s `minimum_coverage` was
bumped 76 → 78. _Reachable-subset:_ `ansible_live`'s tick/timer scheduling
(`tick`/`reset_tick`/`tick_interval`) is left uncovered — deterministic
time-driven scheduling not meaningfully unit-testable here.

### Admin — top-level shell

`admin_live`. _Scope:_ 1 file (fold into an adjacent chunk if trivial).

_Done:_ `admin_live_test.exs` covers the most coupled admin page so far — it
reads two contexts (`Course.list_active_classes` + per-class
`Servers.list_all_servers_in_group`), overlays the ansible-queue presence, and
drives the per-server real-time tracker. Each test asserts a whole-page
projection (`%{ssh_public_key, stats, classes}`): the three stat cards (ansible
queue `pending/demand`, ansible jobs, connected count — each with its
success/warning/secondary variant) and the class list, each class section
projected to its servers as `{server_id, :connected | :not_connected}` (the
server card's rendering is covered through the server pages, so only identity
and connection state are pinned here). This **covers `admin_class_servers_live`
through the page** (a pure presentational child `live_component` with no route
of its own), per the components-through-the-page canon. Coverage of the mount,
the class lifecycle handlers (`:class_created` active/inactive, `:class_updated`
rename / become-inactive, `:class_deleted`), the server lifecycle handlers
(`:server_created` + `track`, `:server_updated` move-in vs. in-place,
`:server_deleted` + `untrack`), the `{:server_state, …}` update, and the
ansible-queue `:join`/`:update`/`:leave` diffs.

The chunk reused both seams established earlier rather than introducing new
ones: the `TrackerClient` façade (from [Admin — ansible
views](#admin--ansible-views)) for `Tracker.list("ansible-queue")`, and the
`ServerTrackerClient` façade (from the server pages) for the `ServerTracker`
GenServer calls
(`start_link`/`server_state_map`/`track`/`untrack`/`update_server_state_map`).
The recurring **clock gap** was fixed (flag for review): the
`:class_created`/`:class_updated` handlers read `DateTime.utc_now/0` to evaluate
`Class.active?/2` and now use `ArchiDep.Clock.now()`.

One latent **type** bug was fixed and flagged: `update_server_state_map/2`
legitimately stores `nil` for a server that has left or been untracked (its
`server_state_update` value is `ServerRealTimeState.t() | nil`), but the
`ServerTrackerClientBehaviour` callback (and the `ServerTracker` `@spec`) typed
the state map's values as `ServerRealTimeState.t()` only — so the real shape
failed the Hammox contract once the page went through the mocked client. The map
value type is now `ServerRealTimeState.t() | nil` in the behaviour, the impl
`@spec`, and `admin_live`'s `real_time_states_for/2` / `count_connected/1`
specs.

_Test-isolation:_ the page's class list is driven by the shared, non-sandboxed
`"classes"` PubSub topic, so a concurrent class test can inject classes after a
broadcast. Following the documented list-page convention (full page at mount;
targeted assertions after a broadcast), the mount tests assert the whole class
list while the post-broadcast tests assert the affected class section by its
test-unique name plus the (pollution-free) stats; the file stays `async: true`.

_Coverage ratchet:_ with the suite at 81.4%, `coveralls.json`'s
`minimum_coverage` was bumped 78 → 80. _Reachable-subset:_ the few defensive
branches not driven through the UI are left uncovered (`admin_live` is at
92.7%).

### Dashboard

`dashboard_live`, `my_servers_live`, `components/what_is_your_name_live`.
_Scope:_ 3 files.

_In progress — `my_servers_live` landed first._ `my_servers_live_test.exs`
covers the student-facing servers page: the per-server card projection at mount
(keyed by each card's details link, holding the displayed name and real-time
status badge), the empty state, the `retry_connecting` delegation, all four live
PubSub handlers (`:server_state`, the owner-add vs. unrelated-no-op
`:server_created` split, `:server_updated` rename, `:server_deleted` removal),
and the hosted `new_server_dialog_live` (validate wiring, a full create pinning
the exact submitted data map, and the create-failure error rendering) — which
also exercises `server_components`/`server_form_component` through the page. A
root variant covers the `list_server_groups` branch and the group selector. The
page is at 96.2% and the dialog at 90.0%. Two source changes were needed and are
flagged for review: (1) `my_servers_live` now reaches the tracker through the
`ServerTrackerClient` seam instead of calling the `ServerTracker` GenServer
directly, the established adoption already proven on `server_live`; (2) the
always-rendered `new_server_dialog_live` called the schema query
`ServerOwner.fetch_authenticated/1` directly, which raises off any mocked auth
and made the page un-mountable in a test — it now goes through a new
`Servers.fetch_authenticated_server_owner/1` context facade (Behaviour callback

- `ReadServerGroups` impl), the sibling of
  `fetch_authenticated_server_group_member/1`. One latent type bug was fixed and
  flagged: `ServerTrackerClientBehaviour` declared the
  `server_state_map`/`update_server_state_map` maps with `required` keys, but
  the map is legitimately empty when a principal has no servers; the keys are
  now `optional(...)`, the accurate model (the same `required` → `optional`
  map-type fix made earlier on `Types.server_properties`). No clock gap surfaced
  (`my_servers_live` stamps no time). _Coverage ratchet:_ with the suite at
  69.4%, `coveralls.json`'s `minimum_coverage` was bumped 66 → 68. _Remaining:_
  `dashboard_live`, `components/what_is_your_name_live`,
  `server_help_component`, and the edit/delete server dialogs hosted on
  `dashboard_live`.

_In progress — `dashboard_live` (the landing page) landed next._
`dashboard_live_test.exs` covers the page across its student states and its
hosted dialogs (`dashboard_live` at 95.0%). Every render test asserts a **single
whole-page projection** — `%{welcome, name_prompt?, call_to_action,
change_username_dialog?, servers}` — by equality, so a conditional-logic bug
that leaks one region onto a page that should show another fails a test; this
drove a new canon rule, [Project the whole page state, not one region in
isolation](../app/docs/testing.md#asserting-the-dom-a-meaningful-projection-not-exact-markup).
The projection pins the data each region owns, not just its presence: the
**welcome screen** asserts the rendered SSH key fingerprints exactly (a fixed
fingerprint pair with a deterministic human form) plus the username and
password, and the **call to action** distinguishes the `:student` and `:root`
variants. The interaction paths are covered too: the **what-is-your-name
prompt** and **change-username dialog** (validate wiring + a configure
submission pinning the exact data map), the always-rendered
`new_server_dialog_live` (full create / error), the **edit server dialog**
(rendered on a connection problem, pinning the whole update data map), and all
live handlers. The live-update tests publish **real broadcasts** (the production
path) rather than sending synthetic messages: the page subscribes to each owned
active server on both its per-server topic and the owner's servers topic, so a
broadcast is delivered more than once — real behaviour the tests now exercise
(the tracker is stubbed to tolerate the redundant deliveries; the assertions pin
the converged page). Real-time state updates arrive directly from the tracker
process, so those are still sent.

Two source changes, both flagged for review. (1) The established seam adoption
already proven on `my_servers_live`/`server_live`: `dashboard_live` reaches the
tracker through the `ServerTrackerClient` seam instead of the `ServerTracker`
GenServer, so the page is mountable under test. (2) The **wall-clock gap is
fixed, not deferred**: `Student.can_create_servers?/2` already accepts `now`, so
`mount/3` now reads `Clock.now()` and the template calls the 2-arity version
with the injected clock — the page no longer reads wall-clock time, and the
tests pin `@now`. One **latent DOM bug fixed** (this is exactly the kind of
issue these tests exist to surface): the page renders the new-server and
edit-server forms simultaneously, and both built their form with `to_form(…, as:
:server)`, so their inputs collided on ids like `server_active` — duplicate DOM
ids that LiveView warns are undefined behaviour. Each dialog now passes a
distinct `id:` to `to_form` (`"new-server-form"` / `"edit-server-form"`), so the
inputs are unique. _Coverage ratchet:_ with the suite at 71.2%,
`coveralls.json`'s `minimum_coverage` was bumped 68 → 70.

_Done (`server_components` and `server_help_component`):_ both server view
component modules are now unit-tested in isolation with `render_component/2`,
each to 100% line coverage. `server_help_component_test.exs` drives every
troubleshooting branch through a single whole-output projection (`%{inactive,
timeout, refused, auth_failed, key_exchange, property_mismatch, open_ports,
success}`) asserted by equality, so a guard that leaks the wrong help note fails
a test; it pins the dynamic bits each note owns (the SSH port in the timeout
note, which of the hardware/hostname/swap steps the property-mismatch note
shows) and covers the negative guards (busy, unhandled problem, wrong connection
state). `server_components_test.exs` projects each card to a whole map (`%{name,
badge, color, busy?, body, problems, retry, edit?, details?}`) and exhausts the
state machine: every `server_card_badge`/`server_card_class`/`server_card_body`
branch across all eight connection states with and without problems, all
connected jobs, the retry-connecting countdown (deterministic under a pinned
clock) including the root attempt counter, the post-setup timeout-problem
filter, and the edit/details/retry affordances. `admin_server_card` is covered
the same way through a `%{owner, conn, short_status, body, busy?}` projection.
Every `server_problem/1` clause is pinned by `%{severity, text, retry}` — both
the root and non-root rendering, the ansible failure summary and its spinning
retry action, the open-ports list, the key-exchange fingerprint listing (valid /
none / invalid), and every `server_expected_property_mismatch` sentence — and
`server_owner_name/1` covers its three resolution clauses. One source change,
flagged for review: `LoadingHelpers.loading_messages/0` was added so the
`gathering_facts` body (a `random_loading_message/0`) can be asserted by
membership in its complete known set rather than a weak non-empty check.
_Coverage ratchet:_ with the suite at 75.8%, `coveralls.json`'s
`minimum_coverage` was bumped 70 → 74.

_Box closed:_ all three files are covered — `dashboard_live` and
`my_servers_live` have dedicated tests and `components/what_is_your_name_live`
is page-covered through `dashboard_live_test.exs` (its validate/configure events
asserted there). The edit/delete server dialogs hosted on the dashboard are
exercised through the page; the standalone delete dialog lives on `server_live`,
out of this box's scope.

### Profile (remainder)

Most of the profile work is folded into the [web-layer canon
task](#canon--web-layer-liveview-test-conventions), which brings
`profile_live_test.exs` up to canon (the six gaps listed there, including the
`ChangeUsernameDialogLive` form and the `student_updated` PubSub handler). What
remains here is any focused, standalone coverage of the `current_sessions_live`
component not already exercised through the profile page — e.g. the pure
`expired?/1` / `expires_soon?/1` / `expires_at/1` helpers in isolation. _Scope:_
1 file.

_Done:_ `current_sessions_live_test.exs` covers the pure threshold helpers
`expired?/2` and `expires_soon?/2` exhaustively at their boundaries (the `< 0`
expiry boundary and the `< 2 days` "soon" threshold, each pinned at the
threshold and one second either side, plus the already-expired case) under plain
`ExUnit.Case`. `expires_at/1` is **not** re-tested: it delegates to
`UserSession.expires_at/1`, already covered exhaustively in
`user_session_test.exs`. The rendered three-state badge wiring stays asserted
through the profile page's sessions table. The split — full logic/boundaries in
the isolated helper test, wiring in the page, no re-testing of delegations — is
now documented as canon under [Pure helpers on a LiveView or
component](../app/docs/testing.md#pure-helpers-on-a-liveview-or-component). The
profile-page canon work (shared-fixture overrides, the `{type, message}`
notification projection via `flash_notifications/1`, the both-principals page
rule, the static-render assertion, and the dialog `closed` no-op) landed with
the [web-layer canon task](#canon--web-layer-liveview-test-conventions).

### Canon + tests — channels

_Context:_ depends on the foundations [`ChannelCase`](#add-a-channelcase).

🧭 Establish the `Phoenix.ChannelTest` pattern and cover `user_channel.ex` +
`user_socket.ex` (connect/auth, join, `handle_in`/`handle_info`). Small enough to
be canon and coverage in one reviewed chunk. _Scope:_ 2 files.

_Done:_ both files are covered (`user_socket_test.exs`, `user_channel_test.exs`)
and the canon is documented under [Channels](../app/docs/testing.md#channels).
The key translation: channels are **web-layer citizens** (contexts
Hammox-mocked, clock injected, `verify_on_exit!`) but with **real PubSub**, and
— having no DOM and no `handle_in` — their observable contract is the **`join`
reply plus the pushed events**, asserted wholly by `==`. The settled
conventions: (1) the initial session data is the join _reply_, not a `"session"`
push (the channel dedups against the last-sent data), so a fresh join replies
with the session data, pushes `"cloudServerData"`, and `refute_push`es
`"session"`; (2) `refute_push` is the channel analogue of the DOM
presence/absence rule — it pins every dedup branch (a server event never
repushes `"session"`; a no-op student update repushes neither); (3) identity
filtering is enforced by the keyed subscription topic, so the
`principal_id`-pinned `handle_info` heads are defensive and tests drive only
deliverable messages (broadcast via the real `*.PubSub.publish_*` helpers); (4)
connect/auth drives `connect/3` through the real handler with a signed token,
mocking `validate_session_id`, with the token as the verifiable-exception.
`ChannelCase` gained the `LiveCase`-style mock setup (default `Clock.Mock` stub,
`verify_on_exit!`) and a `sign_user_socket_token/2` helper.

_Latent bug fixed (flag for review):_ the recurring **clock gap** — `join`,
`:server_created` and `:server_updated` read `DateTime.utc_now()` directly, so
the `Server.active?/2` filtering of `active_servers` was unpinnable; all three
now take `now` from `Clock.now()`, matching every prior chunk.

_Coverage (`user_socket.ex` 100%, `user_channel.ex` 83%):_ the remaining
`user_channel.ex` lines are the two server-list **refresh** mappers
(`update_class_of_active_servers` / `update_student_of_active_servers`, fired by
`:class_updated` / `:student_updated` on a non-empty `active_servers`). They are
**deliberately deferred**: their effect is to refresh the `group` /
`group_member` of an active server — fields the `cloudServerData` payload omits,
so they are invisible to the pushed-events contract — and they call
`ServerGroup.refresh!` / `ServerGroupMember.refresh!`, which the [DDD
plan](./ddd.md#sequencing-with-the-testing-plan) reshapes; per the coordination
note they ship with the `refresh!` work to avoid writing those tests twice. The
cheaply-observable list mutations (drop-on-delete, replace-on-update) are
covered.

### Canon + tests — auth controller & plugs

🧭 ConnCase request tests for the auth controller (`auth.ex` controller +
`auth_html`), `live_auth.ex`, and the auth plugs/pipelines in the router.
Establish the request-test canon (redirect/halt/assign assertions, authenticated
vs. anonymous pipelines) and cover these in one or two reviewed chunks. _Scope:_
auth controller, `live_auth.ex`, router pipelines.

_Done in two chunks._ **Chunk 1 (auth controller):** `auth_controller_test.exs`
covers every action as a full request test — `login` (render + authed redirect),
`configure_switch_edu_id_login`, `log_in_with_link` (valid / remember-me-and-
return-path / malformed / invalid), the Switch edu-ID `callback` (success /
unauthorized / failure), `generate_csrf_token` and `generate_socket_token`
(root, student, anonymous), `impersonate`, `stop_impersonating`, and `logout`.
It settled the **ConnCase request-test canon** in
[`docs/testing.md`](../app/docs/testing.md#plumbing-router-plugs-auth): a single
whole-response projection asserted by `==` (redirect target + whole session
minus the persisted flash + flash notifications + remember-me-cookie state), the
conn-level flash-notification projection, CSRF bypass for mutation requests
(`Plug.CSRFProtection`'s documented skip), non-deterministic tokens via
`assert_secure_random_token`/`Phoenix.Token.verify`, and the convention for an
action fronted by a third-party auth plug (invoke the action directly with the
injected `ueberauth_auth`/`ueberauth_failure` assign; the pure IdP-redirect
`request` action gets no test). Two latent bugs were fixed and flagged: the
`log_in_with_link` `with` had no `else` clause for `Base.decode64/1`'s bare
`:error`, so a malformed token crashed with `WithClauseError` instead of the
intended invalid-link redirect (fixed with a normalizing `decode_link_token/1`);
and the `callback` built the `emails` as a `MapSet` while the
`switch_edu_id_login_data` type and every other caller use a `list` (benign at
runtime via `Enum.map`, but a contract violation Hammox caught — now a
deduplicated list). A high-fidelity end-to-end OIDC test against a fake IdP is
recorded in [`docs/future-work.md`](../app/docs/future-work.md).

**Chunk 2 (plugs, pipelines, live_auth):** `auth_test.exs` pins the
security-relevant **remember-me cookie authentication** path (a valid signed
cookie authenticates the request and copies its token into the session — only
the invalid-cookie redirect was asserted before) and the `set_current_path`
plug; `live_auth_test.exs` pins the on_mount **success** branch by mounting the
lightest authenticated page and asserting the `"authenticated"` push_event as a
whole `ClientSessionData` for a root (`student: nil`) and a student. The shared
cookie/session helpers (`secret_key_base/0`, `put_user_token_in_session/2`,
`put_user_token_in_remember_me_cookie/2`) moved from `LiveCase` to `ConnCase` so
both case templates share them. `auth.ex`/`live_auth.ex` were already ~fully
line-covered (every branch executed by Chunk 1 + the LiveView suite), so Chunk 2
was assertion completeness, not new coverage. Deliberately left untested:
`conn_metadata/1` (already pinned indirectly by Chunk 1's metadata matcher; a
dedicated unit test belongs to the helpers chunk) and the framework pipeline
plugs (`put_secure_browser_headers`/CSP, `Plug.SSL`, the dev-only `:dev`
pipeline). No clock gap surfaced — the auth layer delegates time to the mocked
`Accounts` context.

### Canon — components & web helpers

_Context:_ helpers and components are mostly pure functions and stateless
components — fast to cover once a canon exists. Several helper tests already
exist (`date_format_helpers_test.exs`, `data_helpers_test.exs`, …) and can serve
as the starting point.

🧭 Pick `core_components` + one web helper and establish how we render/assert
function components (Floki) vs. how we unit-test helper functions. Get reviewed.

_Done:_ two exemplars landed — `auth_helpers_test.exs` (the pure-helper unit
test) and `core_components_test.exs` (stateless function components) — and the
canon is documented in `docs/testing.md` under "Helpers & components". The
settled conventions:

1. **Pure helpers** are tested under plain `ExUnit.Case` with exact per-branch
   assertions; `auth_helpers_test.exs` pins every clause of the six predicates
   (each falsifying branch of `can_impersonate?/2` individually). The **doctest
   stance** was settled: doctests are legitimate coverage for a simple,
   self-evident pure function (the existing doctest-only
   `date_format_helpers_test.exs` stays as-is), and branch-dense helpers get
   explicit ExUnit tests. The delegation rule was applied — `username/1` is a
   `defdelegate` and is not re-tested.
2. **Function components** are rendered under `LiveCase` and asserted as a
   semantic DOM projection by `==`. Newly settled (no prior test rendered a
   _slotted_ component): render attr-only components with `render_component/2`
   (as the existing component tests do) but slotted components through an `~H`
   template with `rendered_to_string/1`, since the `inner_block` form of
   `render_component/2` is unreadable. The projection discipline for these
   styling-heavy core components: assert the displayed text / slot content and
   **never** the spacing/layout classes (`no_data/1`, `data_display_element/1`),
   pin a class only where it is the **semantic variant marker** (the `note-info`
   / `note-warning` wrapper tokens, mirroring how `events_components_test.exs`
   pins badge colours), and assert the `:global` `rest` passthrough contract.

_Backlog correction (flag for review):_ this task and the [web-layer
canon](#canon--web-layer-liveview-test-conventions) say "Floki", but the project
standardized on **LazyHTML** (via the `HtmlTestHelpers` support module, the same
engine Phoenix LiveView uses internally) — the canon text says LazyHTML. _No
latent bug surfaced:_ unlike the business-layer spikes, these helpers/components
are trivial pure code with no clock, `with`/`else`, or policy to misfire.

### Web helpers (remainder)

The untested helpers in `archidep_web/helpers` (auth, form, conn, socket,
`live_view`, dialog, `user_agent`, student). Split into 2 chunks if needed.
_Scope:_ ~8 files.

_Done:_ the whole `archidep_web/helpers` directory is now covered, finished in
one pass (`auth` and `date_format` predate this chunk). Seven new test files
(`form_helpers_test.exs`, `socket_helpers_test.exs`,
`user_agent_format_helpers_test.exs`, `student_helpers_test.exs`,
`live_view_helpers_test.exs`, `dialog_helpers_test.exs`,
`conn_helpers_test.exs`) applying the helper canon, all under plain
`ExUnit.Case` except `conn_helpers_test.exs` (`ConnCase` for the built conn).
Each branch is asserted by exact value: `tmp_boolify/2`'s three branches,
`format_user_agent/1`'s recognized/unknown outcomes,
`student_not_in_class_tooltip/1`'s three clauses (nested `Student → User →
Student → Class` graphs built in memory via the course factory), and
`live_socket_id/1`.

Three assertion shapes the canon spike did not exercise were settled and added
to the [Pure helper modules](../app/docs/testing.md#pure-helper-modules) canon —
all applications of the whole-value rule, none of them new policy: (1) a
**side-effecting** helper (`set_process_label/2,3`, all five arities) is pinned
by its observable effect, `:proc_lib.get_label(self())`, asserted by exact
string (OTP 28); (2) a **`JS`-command builder** (`open_dialog/1`,
`close_dialog/1`) is asserted as the whole `Phoenix.LiveView.JS` struct by `==`,
as the server component tests already do for `JS.push`; (3) a
**conn/socket-taking** helper is driven with a built conn / minimal
`%Phoenix.LiveView.Socket{}` and its whole returned value asserted by `==` —
`conn_metadata/1` against a whole `%ClientMetadata{}`, and
`validate_dialog_form/4`'s resulting assign as a whole `Phoenix.HTML.Form` by
`==` across its apply / validate-ok / validate-error branches.

_No latent bug fixed_ — these are trivial pure helpers. Two minor robustness
observations for the reviewer, neither reachable from current callers (so
flagged, not fixed): `validate_dialog_form/4`'s `with`/`else` only matches
`{:error, %Changeset{}}`, so a validating function returning a non-changeset
`{:error, term}` (which its `@spec` permits) would raise a `WithClauseError` —
but `apply_action` always yields a changeset and every dialog caller returns
one; and `format_user_agent/1`'s `@spec` says `term` while its only clause is
guarded `is_binary`, so a non-binary argument raises `FunctionClauseError`
rather than returning `"Unknown"` — every caller passes the request's user-agent
string.

### Shared components

`core`, `form`, `course`, `server`, `layouts` components. _Scope:_ ~6 files,
split by component family.

_Progress (part 1 — core + form):_ `core_components.ex` is now fully covered —
`core_components_test.exs` gained the two remaining note variants (`more_note`,
`troubleshooting_note`, projected like the existing notes by variant marker /
title / content) and `data_display/1` (its `<dl>` slot content plus the
`:global` passthrough; the responsive/small classes are styling and are not
pinned). New `form_components_test.exs` covers all of `form_components.ex`: the
`field_help/1` and `error/1` slot wrappers, the pure `translate_error/1` and
`process_value/1`, `errors_for/1` (the `used_input?` gate — errors render only
once the field is in the form params **and** an action is set, asserted as the
whole translated-message list including order), and the
`concurrent_modification_warning/1` truth table (each branch projected to
`%{previous, new_badge, text}` by `==`: not-shown, badge style, `:raw` style,
hidden previous value, and the `:value_display` slot override).

Settled a non-obvious fact while writing these: the app's Gettext is
**CLDR/ICU-based, so message placeholders are `{count}` / `{number}`, not Ecto's
default `%{…}`** — `translate_error/1` resolves the app's own ICU messages
(matching the `{number}` the schema tests assert literally). No latent bug
fixed; two minor observations for the reviewer: (1)
`concurrent_modification_warning/1`'s "value has been modified" message uses
`:if={@new_value != @old_value or @new_value != @processed_value}`, but the
container only renders when `@new_value != @processed_value`, so the second
operand is always true inside it and the `@new_value != @old_value` clause is
dead; (2) `translate_error/1` assumes ICU `{…}` placeholders, so a stray
Ecto-default `%{…}` message would render a literal `%` — harmless given the app
defines its validation messages with ICU placeholders.

_Progress (part 2 — course):_ `course_components.ex` is covered by
`course_components_test.exs`. `student_username/1` is projected to `%{username,
suggested}` (the suggestion text or `nil`, covering the confirmed and
unconfirmed branches). `expected_server_properties/1` is projected to the whole
ordered list of rendered `<li>` lines, which exhaustively exercises its four
private formatters through render: the CPU group's singular/plural ICU labels
(`1 CPU` / `2 CPUs`, and likewise cores/vCPUs) and nil-member omission, the
memory group's `… MB RAM` / `… MB Swap`, the OS group's system/architecture join
plus the `{os_family} family` wrapper, the distribution group's three-part join,
the all-unset "No restrictions" line, and the one-line-per-group ordering. The
placeholders resolve through the app's ICU gettext (consistent with the
`{number}` the schema tests assert literally — see part 1). No latent bug.

_Progress (part 3 — layouts):_ `layouts.ex`'s `app/1` application shell is
covered by `layouts_test.exs`, rendered in isolation across the auth/path matrix
and asserted as one whole-shell projection by `==` per test — `%{auth_menu,
top_nav, admin_submenu, course_divider?, material_menu?, content}`. The branches
pinned: the anonymous log-in link vs. the logged-in account dropdown
(Profile/Log out), the extra Stop-impersonating action when impersonating, the
root-only Admin icon, the root-and-admin-path-only admin submenu
(Classes/Ansible/Events) and "Course" divider, and the active-nav highlighting
for `/app`, `/admin`, and each admin subpath (the active state is folded into
the projection as a boolean derived from the highlight class, not pinned as a
styling value, mirroring the badge-colour precedent). No latent bug.

_Scope note (flag for review):_ the sidebar **course-material menu**
(`Material.course_sections/0` / `course_cheatsheets/0`) and the **footer**
(`ArchiDep.Git` / `ArchiDep.Application.version`) render from compile-time
course data and global build metadata, not from `app/1`'s own conditional logic,
and `Material` is not injectable — so the projection covers the material menu by
**presence only** (`material_menu?`) and omits the footer. The per-item material
formatting (slides/exercise/graded icons, section open/closed) is therefore not
unit-tested in isolation; it renders on every page. If that logic ever needs
direct coverage, `Material` would first need to be made injectable.

_Done (part 4 — notifications):_ the `notifications/` Flashy wrappers are
covered (`notifications/message_test.exs`,
`notifications/disconnected_test.exs`). `Message.render/1` is projected to
`%{color, message, dismissible?}` for each of the four notification types (the
`alert-info`/`success`/`warning`/`error` colour is the per-type semantic marker,
as sorted class tokens) plus the non-dismissible case (no `#…-progress` bar).
`Disconnected.render/1` is projected to `%{color, message}`. Notifications are
built with `Message.new/2,3`.

_Scope note (flag for review):_ `Message`'s `icon/1` selects a distinct Heroicon
per type, but each renders as an opaque inline `<svg>` with the same `w-4 h-4`
class and no identifying attribute, so it cannot be asserted without pinning SVG
path markup (which the DOM-projection rule forbids). The per-type branch is
instead covered through the parallel `color/1` marker (both switch on
`@notification.type`); the icon itself is left unpinned.

With all four families covered (core, form, course, layouts, notifications),
this box is checked.

### Canon — testing runtime processes

_Context:_ the server-tracking and Ansible-pipeline _process_ modules are the
last big untested area and the only one with no proven test pattern. Unlike the
business layer they are not `DataCase` unit tests: they involve OTP supervision,
a GenStage producer/consumer with back-pressure, an `ExCmd` subprocess, an
Erlang `:ssh` connection, and `Phoenix.Tracker` presence. The
`ServerManagerState` state machine is already tested in isolation (19 files);
this phase is about the _processes_ around it. Split out from [Servers —
remaining schemas & Ansible
pipeline](#servers--remaining-schemas--ansible-pipeline-overview) because the
scaffolding (supervised processes, subprocess/SSH stubs, drained mailboxes) is a
different discipline from the schema chunks.

🧭 Pick one tractable process — the **`Ansible.Runner`** (its stream parsing and
exit handling, with the actual `ansible-playbook` invocation stubbed) or a
**GenStage** slice — and settle the conventions: how to start the unit under
`start_supervised!`, how to stub the subprocess / SSH boundary (mock vs. a fake
command), how to drive and assert messages without timing flakiness, and whether
each module is reachable as a focused unit test or only as an integration test.
Get reviewed, refactor, agree. Output: a short "how we test runtime processes"
note + the reviewed example. Only once signed off do the follow-up chunks below
become mechanical.

_Done:_ two reviewable exemplars landed and the canon is documented in
`docs/testing.md` under [Runtime processes (GenServers,
GenStage)](../app/docs/testing.md#runtime-processes-genservers-genstage). The
durable techniques the section settles: (1) test the substantive logic as a
**pure state machine** asserted by whole-value `==`, and the GenServer/GenStage
itself only for `init`/dispatch wiring; (2) start the unit with
`start_supervised!` under a **per-test-scoped name** derived from an init-time
value (the pipeline modules' `{:global, {Module, pipeline}}`); (3) give a
spawned process the test's **sandbox connection and mocks** — `Sandbox.allow`/
`Hammox.allow` for lazy readers, shared-mode (`async: false`) when the process
reads the DB in `init/1` (too early to allow), and the rule that a
**boot-started singleton owned by no test must not call injected mocks** from
its always-running paths; (4) **drive then read back, never `Process.sleep`** (a
`call` after a `cast` flushes the mailbox; `assert_receive` on mock sends;
`wait_for_state!` for convergence); (5) stand in for a collaborator with
`GenServerProxy`/`NoOpGenServer`. One-off techniques stayed as test-file
comments per the doc's own guidance.

**Exemplar 1 — `Ansible.Runner` (subprocess boundary).** Settled the "mock vs.
fake command" question in favour of a **mock**: introduced an `ArchiDep.Cmd`
facade (behaviour + `Cmd.Mock`, resolved via `compile_env` to `ExCmd` in
production), mirroring `ArchiDep.Http`/`ArchiDep.Clock`, and rewired `Runner` to
it. `runner_test.exs` drives the facade with canned stream elements of the exact
shape `ExCmd.stream/2` emits (binary chunks then `{:exit, term()}`), covering
both `gather_facts` (the command sent, facts decode joining output split across
chunks, the decodable-error/`msg`, invalid-JSON, unknown branches) and
`run_playbook` (the command incl. variables, per-line event decoding, malformed-
line dropping, exit/`:epipe` passthrough). A **mock** was the right call over a
fake command precisely because it gives deterministic chunk boundaries — which
surfaced a **latent bug** (flag for review): `run_playbook`'s `Stream.transform`
accumulator decoded-and-dropped a chunk that contained no newline instead of
buffering it, so any playbook event split across pipe reads with the first
segment lacking a newline was silently lost. Fixed (`[first_part] -> {[], acc <>
first_part}`) and pinned by a split-across-chunks regression test; a real
subprocess could not have reproduced the split deterministically. (Aside: the
`Runner.gather_facts` spec lists `{:error, :unreachable}`, which the current
code never produces — left as-is, noted here for review.)

**Exemplar 2 — `AnsiblePipelineQueue` (GenStage process).** Split into the pure
half (`ansible_pipeline_queue_state_test.exs`: `State.init`/`store_demand`/
`gather_facts`/`run_playbook`/`server_offline`/`consume_events`/`health`
asserted as whole structs, the embedded `:queue` normalized to its FIFO list for
equality) and the process half (`ansible_pipeline_queue_test.exs`:
`start_supervised!` under a unique pipeline value, the DB-in-`init` read under
shared-mode sandbox, and tasks driven through the client API then asserted as
the exact events dispatched to a real `GenStage.stream` consumer — including the
`server_offline` cast's drop, sequenced before consumption by a synchronous
`health` call). The recurring **clock gap** appeared as predicted: `State`
stamped `last_activity` with `DateTime.utc_now/0`. Resolved by **threading `now`
into `State`** (so the pure tests pin it) while the live GenStage glue passes
wall-clock — because the boot-started singleton pipeline is owned by no test and
therefore cannot call the injected `Clock` (doing so crashes it on the first
demand); this is exactly the boot-singleton rule now in the canon. Production
behaviour is unchanged (the glue still uses wall-clock, just at the boundary).
_Deliberately not asserted (deferred to the chunk above):_ the queue's
`Phoenix.Tracker` presence (`track!`/`update_tracking!`) — it runs during these
tests (a failing `track!` would crash `start_supervised!`) but the registered
entry and its `%{demand:, pending:}` metadata are not read back; and the
boot-cleanup path, which has no fixture here.

### Ansible pipeline — Runner & GenStage

`Ansible.Runner` (subprocess invocation + JSON/JSONL stream parsing + exit-code
handling) and the GenStage pipeline (`AnsiblePipelineQueue` producer with its
task-dropping-when-offline logic, `AnsiblePipelineConsumer`,
`AnsiblePipelineRunner`, `AnsiblePipelineSupervisor`). Stub the
`ansible-playbook` process at the `Runner` boundary so no real Ansible runs.
_Scope:_ ~5 modules; split Runner vs. pipeline if the canon task does not
already cover one. The canon spike already covered `Ansible.Runner` and the
`AnsiblePipelineQueue` producer; the remainder here is the `Consumer`, the
`Runner` task, the `Supervisor`, the queue's **boot-cleanup** path
(`mark_incomplete_playbook_runs_as_timed_out`, untested so far — it needs a
persisted incomplete-run fixture), and the queue's **`Phoenix.Tracker`
presence** (`track!`/`update_tracking!`): the spike's process tests start and
drive the queue, so those run, but the registered `"ansible-queue"` /
`"queue:#{pipeline}"` entry and its `%{demand:, pending:}` metadata are not
asserted. Cover them here by reading the presence back (the
`ServerTracker`/`Phoenix.Tracker` chunk shares this need); note that
`Phoenix.Tracker` is eventually consistent, so the read-back needs
`ProcessTestHelpers.wait_for!` rather than an immediate assertion.

Two decisions carried over from the canon spike:

- **Make the queue `async`-testable by removing the real DB call from `init`.**
  The only reason `ansible_pipeline_queue_test.exs` is `async: false` is the DB
  read in `init/1`; the queue otherwise never touches the DB. Two ways to lift
  it, in order of preference:
  - **Inject the DB collaborator** (preferred when a config mock cannot do the
    job — which is the case here). Pass the module holding the boot-cleanup
    operations on `start_link` (real impl by default, a plain fake in the test),
    behind a behaviour. This keeps the **live** pipeline on the real DB while a
    test injects a fake, so `init` does no real DB work, the producer tests run
    `async: true`, **and** the cleanup becomes unit-testable through the queue
    (fake returns incomplete runs, assert the timeouts dispatched). A
    config-resolved Mox/Hammox mock cannot be used for this `init` call: it is
    owner-scoped, and `init` runs before the test holds the pid (and the boot
    singleton is owned by no test), so the mock has no owner — the same wall the
    injected `Clock` hit. Hence a **plain** fake; recover the contract guarantee
    by `@behaviour` on the real impl plus `Hammox.protect/2` of it in its own
    test. See [Injecting collaborators into a
    process](../app/docs/testing.md#runtime-processes-genservers-genstage).
  - **Gate the cleanup behind a runtime flag** (the `track_on_boot` pattern, off
    in tests) — lighter, but turns the cleanup off in tests, so it must then be
    covered in isolation rather than through the queue.

  Do this **here**, not as a standalone async flip: this chunk has to cover the
  cleanup anyway. Not worth a production change just to parallelize three fast
  tests on its own.

- **Add exactly one end-to-end smoke test.** Every unit test mocks the stage
  boundaries, so nothing yet proves the stages are wired: the `Consumer`'s
  subscription to the producer, demand/back-pressure across the real link, and a
  `Runner` task being spawned per event to invoke `Ansible` + the
  `ServerManager` callbacks. One happy-path smoke test — start the full
  `AnsiblePipelineSupervisor` with a test pipeline, enqueue one task, assert the
  mocked `Ansible.gather_facts` runs and the mocked `ServerManager` gets the
  result — catches wiring regressions the unit tests cannot. The `Runner` task
  runs in a pid the test does not hold, so reach its mocks with
  `Mox.set_mox_global` under `async: false` (this test is integration and serial
  regardless). Keep it to **one** happy path; all branches stay in the unit
  tests, or the smoke test becomes the "too much ceremony" trap.

_Done:_ shipped as three reviewable slices.

**Runner through the facade + unit tests.** `AnsiblePipelineRunner` was the only
module calling `ServerManager` directly instead of the `ServerManagerClient`
facade; the four pipeline callbacks (`online?`, `ansible_facts_gathered`,
`ansible_playbook_event`, `ansible_playbook_completed`) were added to
`ServerManagerClientBehaviour` + `ServerManagerClient` (the GenServer already
declared the behaviour and defined them, so it is a free compile-time check) and
the runner rerouted — a consistency fix, flagged for review. `process_event/1`
is public, so `ansible_pipeline_runner_test.exs` calls it **directly in the test
process** (no spawned-task gymnastics): the owner-scoped `Ansible.Mock` /
`ServerManagerClientMock` and the sandbox stay test-owned. Covers gather-facts
(online ok/error, offline no-op) and run-playbook (not-pending, online
succeeded/failed with the mocked stream, offline→interrupted), asserting the
collaborator calls (pinned args), the DB transition + stored event (whole-value,
helpers adapted from `tracker_test.exs`), and telemetry — the deterministic
`:telemetry.execute` interrupted event exactly, and the `:telemetry.span` stops
by binding their unknowable `duration`/`monotonic_time`/`telemetry_span_context`
from the received event and asserting the whole value (the generated-id
pattern).

**Queue boot-cleanup injection + Tracker presence.** The boot cleanup moved into
an injected store (`AnsiblePipelineQueueStore` + behaviour) passed on
`start_link` (real default, no-op fake in the queue test) — so the queue's
`init` is DB-free and `ansible_pipeline_queue_test.exs` is now `async: true`.
The real store's cleanup is covered directly in
`ansible_pipeline_queue_store_test.exs` (pending/running runs time out with
their finished events; terminal runs untouched; empty no-op), and the queue test
reads back the `Phoenix.Tracker` presence (the deferred
`track!`/`update_tracking!`) via `wait_for!`, asserting the published
`%{demand:, pending:}` (the tracker's own `:phx_ref` bookkeeping is not queue
data, so it is left out — the meaningful-projection rule). Two gotchas worth
recording for the next chunks: the `Postgrex.INET` `/32` round-trip means a run
must be reloaded as the assertion baseline, and `time_out`'s start/finish
ordering validation requires the fixture's `started_at` to precede the pinned
timeout instant.

**Pipeline smoke test.** `ansible_pipeline_supervisor_test.exs` starts the whole
`AnsiblePipelineSupervisor`, enqueues one gather-facts task, and asserts (via
`assert_receive` on pinned-argument mocks) that `Ansible.gather_facts` ran and
`ServerManagerClient.ansible_facts_gathered` was called — proving
Queue→Consumer→Runner-task→Ansible+manager are wired. `async: false` +
`Mox.set_mox_global` (the runner task is a separate pid) with shared-mode
sandbox; one happy path only. Telemetry is not asserted here (it fires in the
spawned task, which the helper's `self()` guard skips). Full suite green (1487
tests), Credo clean, each new file stable over 30–50 repeats.

### Server tracking — SSH connection

`ServerConnection` (the `:ssh`-linked GenServer and its crash/restart behaviour)
and `ServerConnectionState` (the record-based state machine — testable as pure
data even where the GenServer needs a stubbed SSH boundary). Plus
`ServerProblems` (pure problem constructors/predicates), which can fold in here
or into the orchestrator chunk. _Scope:_ ~3 modules.

### Server tracking — orchestrator & Tracker

`ServersOrchestrator` (decides which servers to track; starts/stops per-server
supervisors — its `track_on_boot` gating is already relied on by the use-case
tests), `ServerDynamicSupervisor`, and `ServerTracker` (live state over
`Phoenix.Tracker`, notifying the web layer). Cover the three client/manager
behaviours' real implementations where they carry logic. Test with
`start_supervised!` and `Phoenix.PubSub` assertions. _Scope:_ ~4–6 modules.

To make `ServersOrchestrator` **fully** unit-testable rather than relying on the
inert `track_on_boot: false` path, a few changes work together (deliberately
deferred, not blocking the rest of this phase):

- **Inject the collaborators, not just the subscription.** Today
  `handle_continue(:load_servers, …)` gates three things behind the compile-time
  `@track_on_boot`: the `PubSub.subscribe_server_created/0` call, the
  `Server.list_active_servers/1` read, and the per-server
  `ServerDynamicSupervisor.start_server_supervisor/2` start. A no-op
  subscription MFA alone only neutralizes the first; the read still hits the
  database and the start still spins real supervised processes. Route the read
  and the supervisor through client facades (behaviour + Hammox mock, like
  `ServerManagerClient` / the `*Client` modules already in `config/test.exs`) so
  a unit test can stub the active-server list and assert the exact
  `start_server_supervisor/2` calls, then drive `handle_info({:server_created,
…})` directly with `send/2`.
- **Make "track on boot" a runtime input passed from `Servers.Supervisor`, not
  `compile_env`.** That is what the injected subscription MFA is really getting
  at — moving the decision out of a compile-time global so a test can start the
  orchestrator with tracking on and mocked collaborators. Prefer an explicit
  flag over a no-op MFA, since the flag must also gate the load + starts and
  reads more honestly than a function that silently disables one of three steps.
- **Parameterize the `{:global, __MODULE__}` name** so async tests can each
  `start_supervised!` their own instance (also touches `ensure_started/1`'s use
  of `@name`); align with the existing GenServer-proxy test pattern rather than
  a new approach.
- **Switch `DateTime.utc_now/0` to `Clock.now/0`** in `handle_continue` and
  `handle_info` so the `Server.active?/2` time logic is pinnable for exact
  assertions, consistent with the rest of the app.

These compound with the per-test PubSub topic scope (`ArchiDep.PubSub.Scope`):
the orchestrator stays inert in test today specifically so a non-sandboxed
`server_created` broadcast cannot wake it to query the database outside a
caller's transaction. With `"servers:new"` scoped per test, that concern
dissolves — a test can let the orchestrator subscribe and then drive a real
scoped broadcast and assert it reacts, fully async, leaving `track_on_boot` as a
deployment concern rather than a test-inertness switch.

### Decide exclusions

_Context:_ once the sweep is essentially done and we can see the _actual_
coverage map, lock the policy.

Review what's left uncovered and decide — file by file — whether anything
genuinely untestable (e.g. `release.ex`, `sentry.ex`, `repo.ex`, `mailer.ex`,
`cldr.ex`, `gettext.ex`, generated/boilerplate) should be added to `skip_files`,
or whether we'd rather keep them in the denominator. Deliberately deferred to
here, not assumed up front. _Files:_ `app/coveralls.json`.

### Lock the global threshold

Set `minimum_coverage` to the final target (90%, or higher if we comfortably
exceed it).

### (Optional) Per-critical-path enforcement

ExCoveralls has no per-directory threshold, so if we want stricter floors on
critical code (e.g. **100%** on `servers/server_tracking` state machine and any
other parts we deem critical) we'll add a small custom mix task that reads the
exported per-file stats (`export: "cov"` is already configured), buckets files by
path prefix, and fails CI on any bucket under its target. Decide which paths get
a stricter floor. _Files:_ `app/mix.exs` (alias + task), new mix task module.

---

## Assessment (background)

_The analysis below is the original assessment that justified the backlog above.
It is retained for context; the actionable plan is the backlog._

### What's already in place (and genuinely good)

The support layer is more mature than most Phoenix apps ever get:

- **Three case templates, one per layer**: `DataCase` (SQL sandbox), `ConnCase`
  (request, with `conn_with_auth/2`), `LiveCase` (LiveView, with
  anonymous-redirect assertions and `wait_for_socket_assigns!`).
- **Clean dependency injection for the whole web layer.** Each context facade
  does `@implementation = Application.compile_env!(:archidep, __MODULE__)`;
  `config/test.exs` swaps _every_ context (Accounts, Course, Events, Servers)
  plus `Ansible` and `Http` for Hammox mocks. This is the single most important
  enabler for testing controllers/LiveViews in isolation — and it's wired
  correctly and completely.
- **Hammox contract-checked mocks** for every context behaviour, so mock
  expectations are verified against the real typespecs.
- **Per-context factories** (accounts, course, servers, events, net, ssh) on
  ExMachina + Faker, generating randomized-but-valid data, with `build` and
  DB-backed `insert` both available.
- **A demonstrated pattern for testing the _real_ context logic**, which is
  where most of the uncovered code lives. `Course.Context` maps each behaviour
  callback to a `UseCases.*` module; tests call those concrete modules directly
  under `DataCase`, and even wrap them in `Hammox.protect/2` to contract-check
  the real implementation (see
  `log_in_or_register_with_switch_edu_id_test.exs`). So the global mock swap
  does **not** block context testing.
- **GenServer API/impl split utilities** (`GenServerProxy`, `NoOpGenServer`,
  `ServerManagerStateTestUtils`) — the server-manager state machine is already
  heavily tested this way.
- **Process / Date / Telemetry / HTML (Floki)** helpers, doctests, and excellent
  `CONTRIBUTING.md` documentation describing all of it.

Every layer has a proven exemplar: `profile_live_test.exs` (LiveView + mocks +
auth + notifications), `log_in_or_register…_test.exs` (real use-case + DB +
events), `class_test.exs`/`student_test.exs` (schemas), the
`server_manager_state_*` suite (GenServer). New tests can be written by
pattern-matching on these.

### Where the 35% actually is

Coverage is bimodal — some areas are well-covered, huge swaths are at zero:

| Area                                                      | Coverage       | Notes                 |
| --------------------------------------------------------- | -------------- | --------------------- |
| `servers/server_tracking` state machine, helpers, schemas | good (44–100%) | the deep work is done |
| `archidep_web/profile`, `live_auth`, `live_hooks`         | 90–100%        | the LiveView exemplar |
| **`archidep_web/admin`** (26 files)                       | **0%**         | biggest single block  |
| **`archidep_web/servers`** (11 files)                     | **0%**         |                       |
| `archidep_web/dashboard`, `channels`, `auth` plugs        | 0%             |                       |
| **`course` context** (32 files)                           | **5%**         | 27 files at zero      |
| `accounts` context                                        | 28%            | 15 files at zero      |
| `events` context                                          | 24%            |                       |

The gap is overwhelmingly **the web layer (admin/servers/dashboard LiveViews)
and the context use-cases** — i.e. _applying_ the existing patterns, not
building new ones.

### The three investments worth making before scaling

1. **Shared authentication/setup fixtures (highest leverage).** Right now every
   web test hand-rolls ~15 lines of `user_account` + `session` +
   `conn_with_auth` boilerplate — `profile_live_test.exs` repeats it in all 7
   tests. Across hundreds of new web tests that's the dominant cost and a
   consistency risk. Add named `ExUnit` setup helpers to `ConnCase`/`LiveCase`,
   e.g. `register_and_log_in_root`, `register_and_log_in_student`, returning
   `%{conn, auth, user_account, session}`, usable as
   `setup :register_and_log_in_root`. This alone will roughly halve the size of
   each web test.

2. **Add a `ChannelCase`.** `user_channel.ex` / `user_socket.ex` have no test
   support at all (no `Phoenix.ChannelTest` template). Small to add, but
   required if channels are in scope for 90%.

3. **Configure coverage exclusions and a threshold (makes 90% meaningful).**
   There's no `coveralls.json` today — no `skip_files`, no `minimum_coverage`. A
   meaningful chunk of the denominator is essentially untestable infra
   (`release.ex`, `sentry.ex`, `repo.ex`, `mailer.ex`, `cldr.ex`, `gettext.ex`,
   generated/boilerplate). Add `skip_files` for those and set
   `minimum_coverage: 90` so the metric reflects real, reachable code and CI can
   enforce it.
