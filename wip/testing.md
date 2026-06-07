# Phoenix application testing foundation — assessment

**The testing foundation is strong, modern, and essentially complete. You can
start generating tests at scale now** — every layer already has a working,
demonstrated pattern. There are no _blocking_ fundamentals missing. There are,
however, **three small investments worth making first** that will pay off
heavily over the ~200 files still to cover, plus one config change needed to
make "90%" a meaningful target.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [What's already in place (and genuinely good)](#whats-already-in-place-and-genuinely-good)
- [Where the 35% actually is](#where-the-35-actually-is)
- [The three investments worth making before scaling](#the-three-investments-worth-making-before-scaling)
- [Suggested order of attack](#suggested-order-of-attack)

<!-- END doctoc -->

---

## What's already in place (and genuinely good)

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

---

## Where the 35% actually is

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

---

## The three investments worth making before scaling

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

None of these are blockers — you _could_ start today — but doing #1 and #3 first
will make the bulk generation faster, more uniform, and the target honest.

---

## Suggested order of attack

1. Land the auth fixtures (#1), `ChannelCase` (#2), and `coveralls.json` (#3) —
   a small, self-contained PR.
2. Sweep the **context use-cases** (course → accounts → events) with `DataCase`
   - real `UseCases.*` modules + insert factories. This is where the most code
     and logic-density lives, and the factories already exist.
3. Sweep the **web layer** (admin → servers → dashboard LiveViews) with
   `LiveCase`/`ConnCase` + context mocks, using the new auth fixtures and
   `profile_live_test` as the template.
4. Mop up router pipelines and auth plugs via `ConnCase` request tests.
