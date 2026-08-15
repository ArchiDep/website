# Future work

This document collects work we intend to do but have deliberately deferred —
ideas that are worth recording so they are not lost, but that are not scheduled
for the current round of changes. Each section below describes one planned task:
the problem it solves, why it is not being done now, and a sketch of the
approach so whoever picks it up has a starting point rather than a blank page.

This is a living document. Add a level-2 heading per planned task and re-run
`npm run doctoc` to update the table of contents.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Store SSH public keys rather than their fingerprints](#store-ssh-public-keys-rather-than-their-fingerprints)
- [Break-glass recovery for root users when Switch edu-ID is unavailable](#break-glass-recovery-for-root-users-when-switch-edu-id-is-unavailable)
- [Automated SSH exercise VM setup with Ansible](#automated-ssh-exercise-vm-setup-with-ansible)
- [Dual search system](#dual-search-system)
- [End-to-end Switch edu-ID login test against a fake identity provider](#end-to-end-switch-edu-id-login-test-against-a-fake-identity-provider)
- [Fine-grained student-list refresh instead of a full reload per event](#fine-grained-student-list-refresh-instead-of-a-full-reload-per-event)
- [Define and enforce the Servers context public API](#define-and-enforce-the-servers-context-public-api)
- [Derive audit-log entities from event data instead of re-reading source tables](#derive-audit-log-entities-from-event-data-instead-of-re-reading-source-tables)
- [Keep the server `secret_key` out of the Ansible admin web state](#keep-the-server-secret_key-out-of-the-ansible-admin-web-state)
- [Publish SSH host-key parsing across the context boundary](#publish-ssh-host-key-parsing-across-the-context-boundary)
- [Remaining uncovered code after the 90% coverage push](#remaining-uncovered-code-after-the-90-coverage-push)
- [Let the link tag name a document rather than a source path](#let-the-link-tag-name-a-document-rather-than-a-source-path)
- [Stop publishing source maps with the course assets](#stop-publishing-source-maps-with-the-course-assets)

<!-- END doctoc -->

## Store SSH public keys rather than their fingerprints

**Problem:** Classes and servers store SSH host key _fingerprints_ rather than
the host public keys themselves, and they store them in more than one
representation. The `servers` table has an `ssh_host_key_fingerprints` column,
and the `classes` table has separate `ssh_exercise_vm_md5_host_key_fingerprints`
and `ssh_exercise_vm_sha256_host_key_fingerprints` columns. A fingerprint is a
lossy hash of a key: it is derived from the key but cannot be turned back into
it. Storing the derived value rather than the source means every representation
we want (MD5, SHA256, …) has to be entered and validated separately, the data is
duplicated across columns, and there is no single source of truth from which the
others can be recomputed.

**Why this matters:** Host key fingerprints are entered by hand as `ssh-keygen
-lf` output and compared against the key the server presents when we connect
(the `silently_accept_hosts` callback in the servers context). If we stored the
public key instead, any fingerprint representation could be derived on demand
for both display and comparison, and a key would be entered once rather than
once per hash algorithm.

**Proposed approach:** Store the host public keys (one per line, in the format
produced by `ssh-keyscan` or found in a `known_hosts` file) and derive
fingerprints from them wherever a fingerprint is currently displayed or matched.

- Replace the fingerprint columns with a public-keys column on both `servers`
  and `classes`, or keep the fingerprint columns as a derived cache populated
  from the stored keys.
- Update the admin forms to accept public keys instead of `ssh-keygen -lf`
  fingerprint output, and parse/validate them accordingly.
- Compute MD5 and SHA256 fingerprints on the fly from the stored key for the
  dashboard and the connection-verification callback.

**Open questions to resolve when scheduling this**

- How to migrate existing rows: a fingerprint cannot be reversed into a public
  key, so existing hosts would need to be re-scanned (`ssh-keyscan`) or
  re-entered, possibly via a transition window where both fingerprints and keys
  are accepted.
- Which input formats to accept (raw public keys, `ssh-keyscan` output, full
  `known_hosts` lines) and how strict the parser should be.
- Whether to drop the fingerprint columns entirely or retain them as a
  derived/denormalised cache for queries and display.

## Break-glass recovery for root users when Switch edu-ID is unavailable

**Problem:** Root users authenticate through Switch edu-ID (OIDC). If the
identity provider is unreachable — an outage, a misconfiguration, or an expired
integration — there is currently no way for a root user to log in, which is
exactly when administrative access is most needed (to investigate or mitigate
the incident).

**Why not login links?** The obvious shortcut is to let a login link
authenticate a root account, but we have decided against it (a login link must
never authenticate a root account — enforced in
[`log_in_or_register_with_link.ex`](../lib/archidep/accounts/use_cases/log_in_or_register_with_link.ex)
and covered by its test). A login link is a bearer token carried in a URL, so it
leaks through browser history, proxy and server logs, and `Referer` headers;
root is the highest-privilege principal in the system, so granting it through a
channel with those properties is the wrong trade-off. Login links are the
**student** fallback path and carry that path's looser assumptions. Break-glass
recovery for root deserves its own mechanism with its own controls rather than
being bolted onto the student feature.

**Proposed approach:** Root users generally also control the server the
application runs on (shell access). We can use that fact as the proof of
authorization: a recovery credential that can only be produced by someone with
server access.

- Provide a `mix` task (run on the server) that generates a **short-lived,
  single-use token** and prints it to standard output only. Possession of the
  printed token then demonstrates control of the server.
- Expose a dedicated, clearly-labelled recovery route where a root user enters
  that token to obtain a root session — separate from the normal login flow and
  from the login-link route.
- Design the token with tight controls from the start: a short TTL (minutes),
  single use, bound specifically to a root account, rate-limited at the entry
  endpoint, and fully audited via a stored event so every break-glass login is
  visible in the audit log.

**Open questions to resolve when scheduling this**

- Where the token is stored and validated (reuse the `login_links` table with a
  root-specific path, or a dedicated schema/table for recovery tokens).
- Whether the `mix` task targets a specific root account (by email) or mints a
  generic root recovery session.
- How the recovery route is protected against being reachable in normal
  operation (feature flag, separate pipeline, or always-on but heavily audited
  and rate-limited).

## Automated SSH exercise VM setup with Ansible

**Problem:** Each class has an SSH exercise VM that students connect to as part
of the course. Setting it up — creating an account per student, installing their
keys, configuring it — is currently a manual process that is time-consuming and
error-prone, and it has to be redone or adjusted as the class roster changes.

**Why we can automate it:** The application already has everything it needs. It
runs an Ansible pipeline (a GenStage queue feeding the `setup.yml` playbook) to
provision students' own cloud servers, and the course context already knows
every registered student of a class. The same machinery could provision the
exercise VM from the class roster instead of doing it by hand. The class schema
already carries the exercise VM's host key fingerprints
(`ssh_exercise_vm_*_host_key_fingerprints`), so the VM is already a first-class
concept on the class — it is just not something the pipeline acts on yet.

**Proposed approach:** Model the exercise VM as a managed server of its own kind
and drive it through the existing Ansible pipeline.

- Introduce a distinction between student-owned cloud servers and other kinds of
  servers (the exercise VM, and any future managed server) so the exercise VM
  has its own lifecycle and playbook rather than being treated as a student
  server.
- Add an Ansible playbook for the exercise VM, registered in the playbooks
  registry alongside `setup.yml`, that creates one account per registered
  student and installs each student's authorised key.
- Re-run the playbook when the roster changes so accounts stay in sync with the
  class's registered students.

**Open questions to resolve when scheduling this**

- How to model the exercise VM as a distinct kind of server: a `kind`/`type`
  field on the existing `servers` schema, a dedicated schema, or attaching it
  directly to the class.
- Where the exercise VM is hosted, and how the application reaches it to run
  Ansible (the same SSH/connection model as student servers, or something
  separate).
- How per-student accounts and keys are provisioned and de-provisioned as
  students are added to or removed from the class.
- What triggers the playbook run (manual admin action, automatically on roster
  changes, or both) and how this interacts with the per-student active-server
  limits enforced for cloud servers.

## Dual search system

**Problem:** Course search is powered by Lunr. At build time a Jekyll plugin
extracts the searchable content of every page into `search.json`, a TypeScript
script turns that into a serialised Lunr index (`lunr.json`), and the client
loads both files and searches entirely in the browser. This is enough for basic
search, but a fully client-side index is limited in scalability and in the
advanced features (typo tolerance, ranking, faceting) we might want.

**Why keep Lunr at all?** A purely static, dashboard-free build of the course
must remain possible for archival and as a GitHub Pages backup (see [Death of
Jekyll — Goals and
Constraints](../../wip/death-of-jekyll.md#goals-and-constraints)). That build
has no backend, so it cannot depend on an external search service. Lunr works
offline from static JSON, so it is the right fallback for the archival build
even if the live application uses something more capable.

**Proposed approach:** Run two search backends from the same source data — a
richer engine (e.g. Meilisearch) for the live Phoenix application, and Lunr for
the static archival build.

- Keep `search.json` as the shared, build-time source of searchable content.
  Index generation is already decoupled from extraction (the Jekyll plugin only
  writes `search.json`; a separate script builds `lunr.json`), so a second
  indexer can consume the same file.
- Add a Meilisearch indexer that populates a search service from `search.json`,
  and have the live application query it.
- Have the client choose its backend: the richer engine when the application is
  available, falling back to the existing Lunr index for the static build.

**Open questions to resolve when scheduling this**

- Where Meilisearch runs and how it is deployed and kept available alongside the
  application.
- How the client selects a backend (build-time flag for the static build,
  runtime feature detection, or graceful fallback when the service is
  unreachable).
- How and when the live index is (re)built and kept in sync with course content
  as it changes.
- Whether result formats and highlighting can be unified across the two backends
  so the search UI does not need two code paths.

## End-to-end Switch edu-ID login test against a fake identity provider

**Problem:** The Switch edu-ID callback action (`AuthController.callback/2`) is
fronted by the third-party `plug Ueberauth` (the `Ueberauth.Strategy.Oidcc`
strategy), which performs the OpenID Connect token exchange, ID-token/nonce
verification, and userinfo fetch before our action runs. Its controller tests
therefore cover only _our_ logic — they invoke the action directly with the
`ueberauth_auth` / `ueberauth_failure` assign the plug would have produced. The
glue we do not own (the OIDC request phase that sets `state`/`nonce`, and the
callback phase that validates them and the ID token) is exercised by no test.

**Why it is not being done now:** A faithful test must stand up a fake OpenID
Connect provider, because the configured issuer is the real
`https://login.test.eduid.ch/` and a through-router request would trigger live
discovery and token/userinfo HTTP calls. That is a sizeable, self-contained
scaffolding effort disproportionate to the remaining auth-controller coverage,
so the action-level tests ship first.

**Proposed approach:** Add an integration test that drives the full flow against
a fake IdP (e.g. `Bypass`) serving the discovery document, JWKS, token, and
userinfo endpoints, with the test issuer pointed at the Bypass URL. Walk the
real request phase (assert the redirect to the provider and the stored
`state`/`nonce`), then the callback phase with a matching authorization code and
a signed ID token, and assert the resulting login. This complements — does not
replace — the action-level tests, which stay as the fast, logic-focused
coverage.

**Open questions to resolve when scheduling this**

- Whether `ueberauth_oidcc` can be pointed at a Bypass issuer cleanly in the
  test environment, including how its provider-configuration worker is started
  and refreshed.
- How to mint a signed ID token (and JWKS) the strategy will accept, with a
  nonce matching the one stored during the request phase.
- Whether this lives under `ConnCase` or needs a dedicated integration setup
  (it is not async-safe if it mutates global issuer configuration).

## Fine-grained student-list refresh instead of a full reload per event

**Problem:** The live student list on the admin class page keeps itself current
with `Course.refresh_class_students/4`, which reloads **every** student of the
class from the database on **every** relevant broadcast — a student created,
updated, configured, deleted or imported, or a linked account changing
(`:preregistered_user_updated`). This is a deliberately coarse projection: one
cross-context DB read per event regardless of how small the change is. It is the
one live read-model in the web layer that does not follow the same
incremental-merge pattern the others already use — `Course.refresh_classes/2`
merges a single class into the cached list in memory (prepend on create,
`Class.refresh!` the matching element on update, reject on delete, re-sort), and
`Course.refresh_student/2` merges a single student with `Student.refresh!`. The
admin student **detail** page (`student_live`) reloads related data on its
events in a similarly coarse way.

**Why it is not being done now:** The full reload is correct and simple, and the
list is small (one class's students), so the extra DB read per event is cheap in
practice. Doing it incrementally is more code and depends on the broadcast
events carrying enough to rebuild a row without a fetch — which is not obviously
true for every case today (a freshly created student's full display shape, the
shape of the `:students_imported` payload, and the student a
`:preregistered_user_updated` event refers to all need checking). It is worth
recording as the natural completion of the read-model pattern, not worth the
complexity yet.

**Proposed approach:** Give `refresh_class_students` the same per-message-type
shape as `refresh_classes`, reusing the existing `Student.refresh!/3`:

- `:student_created` → insert the new student into the list and re-sort (the
  list is name-ordered), if the event carries enough to render a row;
- `:student_updated` / `:student_configured` → `Student.refresh!` the matching
  element in place;
- `:student_deleted` → reject by id;
- `:students_imported` → merge the imported students into the list;
- `:preregistered_user_updated` → find the student whose linked account changed
  and refresh its identity fields (`user`, `active`, username) in memory, the
  same in-memory linkage merge `Course.Student.refresh!` already performs.

Because membership changes (create / delete / import), the whole-list
`LiveRefresh.attach/3` refresher is the right fit rather than
`attach_collection/3` (which cannot express an insertion). Apply the same
treatment to the coarse reloads in `student_live` where an event maps cleanly to
a single-entity merge.

**Open questions to resolve when scheduling this**

- Whether each broadcast event carries enough to build or merge a row without a
  DB fetch — in particular the created-student and imported-students payloads,
  and resolving a `:preregistered_user_updated` event to the student it affects.
- Whether the win justifies the extra code given how small a class roster is; the
  coarse reload may simply be the right trade-off to keep.
- How ordering is preserved on insert (a shared sort helper, as `refresh_classes`
  uses).

## Define and enforce the Servers context public API

**Problem:** The web layer, and in one case the Course context, reach past the
`ArchiDep.Servers` public module (its `defdelegate` surface) into Servers
_internal_ submodules: `ServerTracking.ServerTrackerClient`
(start/subscribe/read tracker state), `ServerTracking.ServerConnectionState` /
`ServerProblems` / `ServerRealTimeState` (rendered by components),
`Ansible.Pipeline` (health), and `Servers.SSH` (host-key parsing — see [Publish
SSH host-key parsing across the context
boundary](#publish-ssh-host-key-parsing-across-the-context-boundary)). Unlike
the read-view/broadcast coupling the DDD plan hardened, these are compile-time
dependencies, so a rename breaks the build rather than failing silently — a
lower-severity smell, but the boundary is still not the single legible surface
the other contexts present.

**Why it is not being done now:** No silent-failure risk, so it is boundary
tidiness rather than correctness. Some of these are also genuinely _read_/view
value types the web is entitled to render (the same way it holds `ServerView`),
so a blanket "wrap everything" would add ceremony without payoff.

**Proposed approach:** When this is picked up, first **decide what actually
belongs in the Servers public API** versus what is a legitimately-shared read
type versus what should stay internal. Likely outcomes:

- Imperative entry points (starting/subscribing a tracker, pipeline health)
  become `ArchiDep.Servers` delegates so the web expresses intent, not
  internals.
- View/value types the web renders (`ServerRealTimeState`, connection state,
  problems) are either published as part of the context's read surface or left
  as-is if they are already effectively read models.
- `Servers.SSH` is resolved by the SSH shared-kernel item above.

**Open questions to resolve when scheduling this**

- The dividing line between "public API", "shared read type", and "internal" for
  Servers — this is the crux and needs deciding before the mechanical wrapping.
- Whether the tracker's process-driving calls fit a behaviour/Hammox contract
  the way the data API does, or stay a direct (but documented) dependency.

## Derive audit-log entities from event data instead of re-reading source tables

**Problem:** [`FetchEvents`](../lib/archidep/events/use_cases/fetch_events.ex)
resolves each stored event's virtual `entity` field at read time by querying
**six** other contexts' tables and traversing their associations (`assoc(ua,
:switch_edu_id)`, `assoc(pu, :group)`, …), dispatched off the stream-type
prefix. This couples the Events context to those contexts' ORM internals and
association graphs, and it re-reads the entity's **current** state, so an event
whose entity was since deleted resolves to `nil` and loses its subject.

**Why the obvious fix is wrong:** Denormalising a separate `{type, id, label}`
descriptor into the event at write time would duplicate identifying data the
event's `data` payload already carries.

**Proposed approach:** Have each context **decode its own events into a
`{entity_type, id, label}` descriptor from the event's stored `data`**, with no
DB read. The event payload is immutable, so this is self-contained (it works
even after the entity is deleted), places the knowledge in the context that owns
the event, and removes the cross-context reads entirely. This also shows the
entity's state **as recorded at event time**, which is what an audit log should
show — though that is a visible change from today's current-state resolution.

- Expose the decoder either on the `Event` protocol (every event already
  implements it) or as a per-context resolver dispatched off the stream prefix
  (as `FetchEvents` already dispatches).
- Branch on the event's `schema_version` for older payload shapes — this is the
  first concrete use of the upcasting hook the schema-version work deliberately
  deferred.

**Open questions to resolve when scheduling this**

- Whether the decoder lives on the `Event` protocol (colocated, but a new
  callback across all impls) or as a per-context function.
- What label an event carries when its `data` holds only an id (e.g. some delete
  events) — best-available id/label versus a DB fallback for those cases only.
- Confirming the admin events UI is content to show event-time state rather than
  current state, and updating it where it renders the resolved struct.
- The already-green resolver behaviour is guarded by the entity-enrichment tests
  in
  [`fetch_events_test.exs`](../test/archidep/events/fetch_events_test.exs); keep
  that guard meaningful as the resolution moves to decoding.

## Keep the server `secret_key` out of the Ansible admin web state

**Problem:** The DDD boundary-hardening plan introduced
[`Servers.ServerView`](../lib/archidep/servers/server_view.ex) specifically to
keep the per-server `secret_key` out of long-lived web-process memory — the web
layer never reads it (its only readers are server-side, `Token.sign` in
`server_manager_state.ex` and `Token.verify` in `server_callbacks.ex`). That
goal is only **partially** met: the Ansible admin pages still hold a full
`%Server{}` — with `secret_key` resident, since `redact: true` only hides the
field from `inspect`, not from the in-memory binary — in long-lived assigns.
[`AnsiblePlaybookRun`](../lib/archidep/servers/schemas/ansible_playbook_run.ex)
has a `belongs_to(:server, Server)` that the fetch queries fully preload;
[`ansible_playbook_run_live`](../lib/archidep_web/admin/ansible/ansible_playbook_run_live.ex)
assigns `playbook_run` and
[`ansible_live`](../lib/archidep_web/admin/ansible/ansible_live.ex) assigns
`playbook_runs`, both long-lived. The admin events view
([`events_components.ex`](../lib/archidep_web/admin/events/events_components.ex))
also pattern-matches a raw `%Server{}` out of `StoredEvent.entity`.

**Why it is not being done now:** The read-view sweep scoped the server lists
and the `StudentView` / `ClassView` projections; the Ansible read models were
out of scope. Nothing in the web layer reads `.secret_key`, so there is no
active credential leak today — this is defense-in-depth (one stray `inspect`,
crash dump, or LiveView state serialization from disclosure), not a live bug, so
it was deferred.

**Proposed approach:** Apply the same read-view pattern to the Ansible read
models — a curated `AnsiblePlaybookRunView` (or projecting its nested server
through the existing `ServerView`) so the raw aggregate, and its `secret_key`,
never reach web-process memory. We will probably introduce a view here.

**Open questions to resolve when scheduling this**

- Whether a dedicated `AnsiblePlaybookRunView` is warranted or the run should
  simply carry a nested `ServerView`.
- How the generic admin events viewer — which renders whatever entity a
  `StoredEvent` references — avoids surfacing the raw `%Server{}` (project or
  redact at that layer too).

## Publish SSH host-key parsing across the context boundary

**Problem:** [`Course.Schemas.Class`](../lib/archidep/course/schemas/class.ex)
calls `ArchiDep.Servers.SSH.parse_ssh_host_key_fingerprints/2` directly inside
changeset validation. This is a **Course write-model depending on a Servers
internal submodule** — not a read-view, not a domain event, and not a documented
shared kernel — the cleanest true cross-context code dependency left in the
codebase. The web layer also reaches into `Servers.SSH` (fingerprint parsing,
`ssh_public_key`), so `SSH` is a de-facto shared utility that is declared shared
nowhere.

**Why it is not being done now:** It works and is correct; this is boundary
hygiene rather than a functional gap, so it is recorded rather than rushed.

**Proposed approach:** Two options —

- **Recognize SSH parsing as a shared kernel** and move it to a neutral,
  context-agnostic location. It is pure, stateless string/crypto parsing with
  more than one consumer (Course + web + Servers), so a shared kernel is honest.
  Preferred.
- **Publish it through a context boundary** (an `ArchiDep.Servers` delegate).
  Cheaper, but keeps a Course→Servers runtime dependency for what is really a
  stateless utility.

This pairs with a broader observation: the web layer reaches into several
Servers internal submodules (`ServerTracking.*`, `Ansible.Pipeline`, `SSH`)
rather than the `ArchiDep.Servers` public API. If a Servers facade is scheduled,
fold SSH into it.

**Open questions to resolve when scheduling this**

- Where a shared SSH kernel would live and what it is named.
- Whether it is worth pairing with a public Servers facade for the tracking and
  pipeline surfaces the web layer currently reaches into directly.
- How it interacts with [Store SSH public keys rather than their
  fingerprints](#store-ssh-public-keys-rather-than-their-fingerprints), which
  would change what is parsed and stored.

## Remaining uncovered code after the 90% coverage push

**Problem:** The Phoenix-application testing plan reached its target — the suite
sits comfortably above 90% line coverage and the global floor is locked at 92%
in [`coveralls.json`][coveralls-config]. No file is hidden from the denominator
(`skip_files` is never configured), so the code that is still uncovered is
uncovered _on purpose_, and this section records those decisions so the gaps are
not mistaken for oversights. They fall into three buckets.

**Deferred to a scheduled refactor — cover it once it is reshaped.** Writing
tests now would only throw them away when the code changes:

- `Monitoring.Metrics` (and the thin `PromEx` / `Web.Telemetry` glue) — waits on
  the metrics/observability rework.
- `Git` and `Helpers.GitHelpers` — wait on the git-integration rework.

**Accepted uncovered — thin plumbing and entrypoints, low test value.** Booting
or delegating code with no branch logic of its own, exercised indirectly if at
all: the `ArchiDep`/`Repo`/`Mailer`/`Sentry`/`Release`/`Endpoint` entrypoints,
the `Mix.Tasks.Recompile` task, the boot-time config assembly (`Config`,
`Web.Config`, `Config.Value`, `Config.Error`), the macro/helper glue
(`Helpers.UseCaseHelpers`), and the context facades
(`Servers.Context`, `Servers.Ansible.Context`,
`Servers.Ansible.PlaybooksRegistry`).

**Coverable later — real gaps we chose not to chase to hit the target.** These
have ordinary logic and could be covered with normal tests when convenient;
they are not blocked on anything:

- Admin LiveView branches: `Admin.Ansible.AnsibleLive`,
  `Admin.Classes.StudentLive`, `Admin.Classes.ImportStudentsDialogLive`.
- `Web.Channels.UserChannel` (partial), `Course.Schemas.User`,
  `Servers.Schemas.ServerGroup` / `ServerGroupMember`.

**Note:** the external-tool compatibility open question the testing plan raised
— whether any SSH smoke test could contribute real coverage instead of only
running in the external job — is **resolved, not deferred**: the SSH client
compatibility test drives the in-process Erlang `:ssh` stack (within the
ecosystem), so it was untagged and now runs in the standard suite, giving
`Servers.SSH.Client.SystemClient` real coverage. Only the Ansible smoke tests,
which drive a foreign tool against a live host, remain `:external`.

## Let the link tag name a document rather than a source path

**Problem:** A cross-reference in the course material is written as a file path —
`{% link _course/205-php-todolist/exercise.md %}` — of which there are 107 across
34 documents. The tag is Jekyll's, and so is its contract: it takes where a file
sits on disk and returns the URL that file is published at. Every cross-reference
in the content is therefore coupled to the layout of the source tree, and any
change to that layout is a rewrite of all of them.

**Why this matters:** A document already has an identity that is not its path.
`ArchiDep.CourseSite.DocumentRef` parses one out of the path — a chapter code, a
slug and which of the four kinds of document it is — because the rest of the
subsystem needs that identity rather than the path. The path is thus a spelling
of a reference the system reconstructs anyway, and the least stable spelling
available: it changes when a file moves, when a deck grows an images directory
and gains a level, or when the directories are renamed. Naming the reference
directly would make the content immune to all three, and shorter to write.

Nothing forces this while Jekyll is in the picture, since the tag has to keep
meaning what Jekyll means by it. Once the Ruby stage is gone the tag is ours, and
this becomes a question of what we want it to say.

**Proposed approach:** Accept a document reference — the chapter code plus the
kind, e.g. `{% link 205 exercise %}` — resolved through the same URL seam the
path form resolves through today, so that an unresolvable reference stays a build
error rather than a broken page. The path form can either keep working through a
transition or be converted wholesale in one pass, the content being the only
caller.

**Open questions to resolve when scheduling this**

- What the canonical spelling is: the numeric code alone is unambiguous, while
  the code with its slug reads better at the call site and states an expectation
  a build can check.
- Whether cheatsheets and slide decks take the same form, given that a cheatsheet
  has a topic rather than a code, and a deck belongs to a chapter.
- Whether the path form is kept at all, or removed once the content no longer
  uses it.
- What the "Source code" link does, since it must keep resolving to a real file
  in the repository and is therefore the one consumer that genuinely wants a
  path.

## Stop publishing source maps with the course assets

**Problem:** [`webpack.config.cjs`](../../course/webpack.config.cjs) sets
`devtool: 'source-map'` unconditionally — `mode` switches on the environment and
`devtool` does not — so a production build emits a `.map` beside every chunk and
writes a `sourceMappingURL` comment into all of them. They are published with the
rest of the assets: a build tree measured here held 267 map files under
`assets/course` totalling 89 MB, the largest single one 4.2 MB. That figure is
inflated by digested copies accumulating in a long-lived local `priv/static`, so
a clean build is smaller, but the order of magnitude is the point.

**Why this matters:** Nothing consumes them. There is no error-reporting service
wired to the course front end, so the maps exist only for whoever opens developer
tools against the deployed site. What they cost is not user bandwidth — a browser
fetches a map only when devtools are open — but the weight of every image built
and every deployment made, on a repository whose image is rebuilt on each push.
It is not a disclosure concern either: the sources are in a public repository.

**Proposed approach:** Make `devtool` depend on the mode the way `mode` already
does.

- `devtool: false` for production if the maps have no consumer, which is the
  situation today.
- `hidden-source-map` instead, if they are ever wanted for error reporting: the
  maps are still emitted, but no `sourceMappingURL` comment points a browser at
  them, and the build step that would use them uploads them rather than
  publishing them.

**Open questions to resolve when scheduling this**

- Whether the dashboard's own assets do the same thing, which was not checked
  when this was written.
- Whether the maps should be kept as a build artifact — uploaded by CI and not
  served — rather than simply not produced.
- Whether the accumulation of stale digested copies in a long-lived
  `priv/static` is worth addressing separately; it inflates any measurement of
  the published tree and is not specific to source maps.

[coveralls-config]: ../coveralls.json
