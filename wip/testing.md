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
  - [ ] [Servers — small schema leftovers](#servers--small-schema-leftovers)
- **2. Web layer — LiveViews & controllers**
  - [ ] 🧭 [Canon — web-layer LiveView test conventions](#canon--web-layer-liveview-test-conventions)
  - [ ] [Servers web — server detail & dialogs (remainder)](#servers-web--server-detail--dialogs-remainder)
  - [ ] [Servers web — forms & components](#servers-web--forms--components)
  - [ ] [Servers web — controllers & retry handlers](#servers-web--controllers--retry-handlers)
  - [ ] [Admin — classes list/detail + class dialogs](#admin--classes-listdetail--class-dialogs)
  - [ ] [Admin — class form components](#admin--class-form-components)
  - [ ] [Admin — students list + student dialogs](#admin--students-list--student-dialogs)
  - [ ] [Admin — student form components](#admin--student-form-components)
  - [ ] [Admin — events views](#admin--events-views)
  - [ ] [Admin — ansible views](#admin--ansible-views)
  - [ ] [Admin — top-level shell](#admin--top-level-shell)
  - [ ] [Dashboard](#dashboard)
  - [ ] [Profile (remainder)](#profile-remainder)
- **3. Channels**
  - [ ] 🧭 [Canon + tests — channels](#canon--tests--channels)
- **4. Plumbing — router, plugs, auth controller**
  - [ ] 🧭 [Canon + tests — auth controller & plugs](#canon--tests--auth-controller--plugs)
- **5. Helpers & components**
  - [ ] 🧭 [Canon — components & web helpers](#canon--components--web-helpers)
  - [ ] [Web helpers (remainder)](#web-helpers-remainder)
  - [ ] [Shared components](#shared-components)
- **6. Runtime processes — server tracking & Ansible pipeline (integration)**
  - [ ] 🧭 [Canon — testing runtime processes](#canon--testing-runtime-processes)
  - [ ] [Ansible pipeline — Runner & GenStage](#ansible-pipeline--runner--genstage)
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

### Canon — web-layer LiveView test conventions

_Context:_ the web layer is tested with LiveCase/ConnCase + context Hammox mocks

- the foundations auth fixtures. Exemplar: `profile_live_test.exs`. This is the
  largest area by file count (77 web files) but the least logic-dense — mostly
  render/interaction/redirect assertions.

🧭 Pick **`server_live.ex` + its three dialogs**
(`new`/`edit`/`delete_server_dialog_live`) and write tests for the main LiveView
plus one dialog. Settle: mounting with auth fixtures, mocking context calls via
Hammox, asserting rendered HTML (Floki helpers), form submission + validation,
flash/notification assertions, PubSub-driven updates, and anonymous-redirect
checks. Get reviewed, refactor, agree. Output: "how we test LiveViews" note +
reviewed examples.

### Servers web — server detail & dialogs (remainder)

Finish `server_live` + `new`/`edit`/`delete_server_dialog_live` not done in the
canon task.

### Servers web — forms & components

`server_form`, `server_form_component`, `server_properties_form`,
`server_components`, `server_help_component`. _Scope:_ 5 files.

### Servers web — controllers & retry handlers

`server_callbacks_controller` (ConnCase request tests), `server_retry_handlers`.
_Scope:_ 2 files.

### Admin — classes list/detail + class dialogs

`classes_live`, `class_live`, `classes_controller`,
`new`/`edit`/`delete_class_dialog_live`,
`edit_class_expected_server_properties_dialog_live`, `admin_class_servers_live`.
_Scope:_ ~8 files.

### Admin — class form components

`class_form`, `class_form_component`, `class_form_ssh_public_key`. _Scope:_ 3
files.

### Admin — students list + student dialogs

`student_live`, `new`/`edit`/`delete_student_dialog_live`,
`import_students_dialog_live`. _Scope:_ 5 files.

### Admin — student form components

`student_form`, `student_form_component`, `import_students_form`. _Scope:_ 3
files.

### Admin — events views

`event_live`, `event_log_live`, `events_components`. _Scope:_ 3 files.

### Admin — ansible views

`ansible_live`, `ansible_playbook_run_live`, `ansible_components`. _Scope:_ 3
files.

### Admin — top-level shell

`admin_live`. _Scope:_ 1 file (fold into an adjacent chunk if trivial).

### Dashboard

`dashboard_live`, `my_servers_live`, `components/what_is_your_name_live`.
_Scope:_ 3 files.

### Profile (remainder)

Extend beyond `profile_live_test.exs` to cover `current_sessions` LiveView.
_Scope:_ 1–2 files.

### Canon + tests — channels

_Context:_ depends on the foundations [`ChannelCase`](#add-a-channelcase).

🧭 Establish the `Phoenix.ChannelTest` pattern and cover `user_channel.ex` +
`user_socket.ex` (connect/auth, join, `handle_in`/`handle_info`). Small enough to
be canon and coverage in one reviewed chunk. _Scope:_ 2 files.

### Canon + tests — auth controller & plugs

🧭 ConnCase request tests for the auth controller (`auth.ex` controller +
`auth_html`), `live_auth.ex`, and the auth plugs/pipelines in the router.
Establish the request-test canon (redirect/halt/assign assertions, authenticated
vs. anonymous pipelines) and cover these in one or two reviewed chunks. _Scope:_
auth controller, `live_auth.ex`, router pipelines.

### Canon — components & web helpers

_Context:_ helpers and components are mostly pure functions and stateless
components — fast to cover once a canon exists. Several helper tests already exist
(`date_format_helpers_test.exs`, `data_helpers_test.exs`, …) and can serve as the
starting point.

🧭 Pick `core_components` + one web helper and establish how we render/assert
function components (Floki) vs. how we unit-test helper functions. Get reviewed.

### Web helpers (remainder)

The untested helpers in `archidep_web/helpers` (auth, form, conn, socket,
`live_view`, dialog, `user_agent`, student). Split into 2 chunks if needed.
_Scope:_ ~8 files.

### Shared components

`core`, `form`, `course`, `server`, `layouts` components. _Scope:_ ~6 files,
split by component family.

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

### Ansible pipeline — Runner & GenStage

`Ansible.Runner` (subprocess invocation + JSON/JSONL stream parsing + exit-code
handling) and the GenStage pipeline (`AnsiblePipelineQueue` producer with its
task-dropping-when-offline logic, `AnsiblePipelineConsumer`,
`AnsiblePipelineRunner`, `AnsiblePipelineSupervisor`). Stub the
`ansible-playbook` process at the `Runner` boundary so no real Ansible runs.
_Scope:_ ~5 modules; split Runner vs. pipeline if the canon task does not
already cover one.

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
