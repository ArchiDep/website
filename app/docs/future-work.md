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
- [Track course progress in the database rather than in frontmatter](#track-course-progress-in-the-database-rather-than-in-frontmatter)
- [Break-glass recovery for root users when Switch edu-ID is unavailable](#break-glass-recovery-for-root-users-when-switch-edu-id-is-unavailable)
- [Automated SSH exercise VM setup with Ansible](#automated-ssh-exercise-vm-setup-with-ansible)
- [Dual search system](#dual-search-system)
- [End-to-end Switch edu-ID login test against a fake identity provider](#end-to-end-switch-edu-id-login-test-against-a-fake-identity-provider)
- [Remaining uncovered code after the 90% coverage push](#remaining-uncovered-code-after-the-90-coverage-push)

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

## Track course progress in the database rather than in frontmatter

**Problem:** Course progress — which chapters have been taught (`done`), are
currently being worked on (`due`), or are coming up (`next`) — is tracked in
YAML frontmatter in the Jekyll `_progress` collection. A Jekyll plugin reads
those files, assigns each chapter a progress state, and bakes the result into
`archidep.json`, which the Phoenix application loads at _compile time_. Updating
progress therefore means editing a Markdown file, rebuilding the static site,
and redeploying the application — there is no way to update it through the UI,
which is awkward for something that changes on every teaching session.

**Proposed approach:** Make the database the source of truth, edited through the
admin console, and have the application drive the static build itself when
progress changes. This depends on the planned move of the static build into
Elixir — a Mix task that renders the whole site, replacing Jekyll (see [Death of
Jekyll — Static build step](../../wip/death-of-jekyll.md#static-build-step)).
Once the application owns the renderer, a progress change can trigger a rebuild
in-process rather than requiring a manual edit-and-redeploy cycle.

- Add a progress model to the course context, edited through the admin console,
  so progress can be updated through the UI without touching frontmatter.
- When the recorded progress changes, enqueue a rebuild of the static content (a
  queue, so rapid successive edits coalesce and rebuilds run one at a time)
  rather than rebuilding synchronously on every save.
- For the dashboard-free standalone/archival build (the GitHub Pages backup and
  the per-year archive, see [Death of Jekyll — Standalone / archival
  mode](../../wip/death-of-jekyll.md#standalone--archival-mode)), which has no
  backend, expose the current progress from the application as a small public,
  read-only API endpoint. The archival build reads its progress from a
  configurable _source_: the live endpoint during the school year, or a frozen
  value (the course considered complete, or a snapshot captured at archival
  time) for the final immutable archive of a year.

**Open questions to resolve when scheduling this**

- The exact shape of the progress source for the archival build: a single config
  knob that is either a URL (live) or a frozen/all-complete value, versus
  separate modes. A single source captured once at archival time keeps the
  per-year archive immutable.
- The granularity of the stored model: per-session `done`/`due`/`next` arrays
  (as today) versus a per-chapter status, and how the per-chapter state is
  computed.
- How to handle the compile-time-to-runtime transition for the material helpers
  that currently load `archidep.json` as module attributes — progress becomes
  dynamic even though the rest of the material is built.
- What the rebuild queue looks like (debouncing, failure handling, whether a
  rebuild blocks serving the previous build) and how it interacts with the
  Elixir static build task once that exists.
- Whether frontmatter is removed entirely once progress lives in the database.

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
- `Course.Helpers.MaterialHelpers` — waits on moving the static build out of
  Jekyll (see [Track course progress in the database rather than in
  frontmatter](#track-course-progress-in-the-database-rather-than-in-frontmatter)).
- `Servers.Schemas.ServerOwner`'s count-mutation changesets and **every**
  `refresh!/2` — the DDD plan reshapes these.

**Accepted uncovered — thin plumbing and entrypoints, low test value.** Booting
or delegating code with no branch logic of its own, exercised indirectly if at
all: the `ArchiDep`/`Repo`/`Mailer`/`Sentry`/`Release`/`Endpoint` entrypoints,
the `Mix.Tasks.Recompile` task, the boot-time config assembly (`Config`,
`Web.Config`, `Config.Value`, `Config.Error`), the macro/helper glue
(`Helpers.ContextHelpers`, `Helpers.UseCaseHelpers`), and the context facades
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

[coveralls-config]: ../coveralls.json
