<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Serving the build in development](#serving-the-build-in-development)
  - [Why this one next](#why-this-one-next)
  - [Three facts the plan rests on](#three-facts-the-plan-rests-on)
  - [Root files become build inputs](#root-files-become-build-inputs)
  - [A build driver usable outside Mix](#a-build-driver-usable-outside-mix)
  - [The watcher](#the-watcher)
  - [The endpoint, the configuration and one small plug](#the-endpoint-the-configuration-and-one-small-plug)
  - [Docker, the host and the documentation](#docker-the-host-and-the-documentation)
  - [Tests](#tests)
  - [Verification](#verification)
  - [Risks and what this leaves open](#risks-and-what-this-leaves-open)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Serving the build in development

A plan for one item of the [death of Jekyll](./death-of-jekyll.md) backlog:
**serve the Elixir-rendered course site through Phoenix in development**. It is
the development half of [Development and production
serving](./death-of-jekyll.md#development-and-production-serving); the separate
static server in production is the other half and is not planned here, so that
backlog item's checkbox stays unchecked until both are done.

---

## Why this one next

Everything the renderer produces has been checked by tests, by HTML and file-set
diffs against Jekyll, and by `LinkCheck` — but **nobody has looked at it in a
browser**. `mix archidep.course_site.build` writes to `app/tmp/course_site` and
nothing serves it; Phoenix still serves Jekyll's `priv/static` at `/`. The bar
for the [HTML fidelity gate](./death-of-jekyll.md#html-fidelity-gate) is
"nothing broken, looks good", and that judgement cannot begin until the build is
reachable. The same mechanism is what the [PDF
export](./death-of-jekyll.md#decouple-pdf-generation-from-production) means by
serving a build locally.

Three decisions were taken before planning: a **watcher** rebuilds on change
rather than a command being run by hand; **both** the Docker and the host
workflows must work; and the **build takes over the root files**, so a served
build depends on nothing else being published beside it.

## Three facts the plan rests on

- **A page served by `Plug.Static` can never carry the live-reload script.**
  `Phoenix.LiveReloader` injects from a `before_send` guarded by
  `conn.resp_body != nil`, and `Plug.Conn.send_file/5` leaves `resp_body` nil.
  The course pages reload today only because Jekyll injects its own script, and
  that goes away with Jekyll's pages.
- **Docker development is already broken**, by earlier items rather than by this
  one. The `app` service mounts neither `./course` — which
  [`CourseSite.Material`](../app/lib/archidep/course_site/material.ex) reads at
  **compile time** — nor `./app/priv/course`, which
  [`ReadCourseSessions`](../app/lib/archidep/course/use_cases/read_course_sessions.ex)
  resolves at runtime. This plan repairs both.
- **Ten files are anchored at the mount point** and only Jekyll publishes them:
  `favicon.ico`, `favicons/heig.png`, `favicons/archidep-512-flat.png`,
  `favicons/archidep-coffee.png` and the six `favicons/archidep-rocket-*.png` of
  the `@favicons` map, all referenced as `{:root_file, _}` by
  [`Chrome.Assigns`](../app/lib/archidep/course_site/layout/chrome/assigns.ex).

---

## Root files become build inputs

Ten files, ~96 KB in all, read from `course/` and published at the build root.

- [`Build`](../app/lib/archidep/course_site/build.ex) gains a `@root_files`
  list beside the existing `@includes` attribute — the same shape for the same
  reason: a named set rather than a directory walk, because `course/favicons/`
  holds seven marks nothing draws. A private reader joins the `reads` chained by
  `site_inputs/1`, which gains a required `:root_files_dir` option.
- **The error kind already exists.** `{:unreadable_source, output_path,
source_path, reason}` is in `@type error()` and already reads correctly in
  `format_error/1`, so a missing favicon needs no new clause and is collected
  beside every other failed read rather than stopping the run.
- [`Site.Inputs`](../app/lib/archidep/course_site/build/site/inputs.ex) carries
  them as `%{String.t() => binary()}` keyed by output path, and
  [`Site`](../app/lib/archidep/course_site/build/site.ex) merges them _under_
  `/archidep.json`, `/version.json` and `/404.html` in `build_files/3`, so a root
  file cannot shadow one. `publish_site/4` already writes with `File.write/2`, so
  there is **no new writing code** and `output_files/1` sees them, which keeps
  `Site`'s claim to be every file a build writes. The bytes travel through the
  plan rather than being copied because they are ~96 KB, unlike the 49 MB of
  files that sit next to a page.
- The Mix task gains a `--root-files` switch defaulting to `../course`.

`LinkCheck` is **not** taught about them. It skips root-anchored URLs because a
build does not own everything under its mount point — `/assets/**` is published
by the digester and served from elsewhere. The clean version of that check is a
root-file manifest on `UrlContext`, so `{:root_file, _}` resolves through it the
way `{:asset, _}` already does; that touches every `UrlContext.new/1` call site
and is a follow-up rather than part of this.

## A build driver usable outside Mix

`ArchiDep.CourseSite.Builder`, new and inside the subsystem — it orchestrates
`Build` and touches no file itself, so the one-filesystem-module rule holds.

```elixir
@spec build(keyword()) :: {:ok, Report.t()} | {:error, String.t(), [String.t()]}
```

It is the chain the Mix task already performs — `site_inputs` → `Site.plan` →
`prepare_output` → `publish_site` → `LinkCheck` — with the `Mix.shell()`
reporting pulled out and the three `format_error/1` functions applied, so a
caller receives strings. `Builder.Report` is a struct of the counts the task
prints, which is what lets a test assert a whole build by `==`.

`:output` takes `:empty | :clean | :swap`. `:swap` renders into
`<output>.staging` and finishes with a new `Build.swap_output/2` — filesystem
work, so it lives in `Build`: remove a stale `<output>.old`, rename the output
aside, rename the staging directory into place, remove the old one. Two renames
rather than one because it needs no symlink; the sub-millisecond window where the
directory does not exist is what the `current`-symlink variant would close, and
production is where that will matter.

`Builder.course_inputs/1` derives the five per-input paths from one course
directory, so the watcher configures a directory rather than five files and the
two drivers cannot disagree about where `course.yml` is. The Mix task's switches
become overrides of it, and its five `case … abort!` blocks collapse into one.

## The watcher

`ArchiDep.CourseSiteWatcher`, new and top-level beside `git.ex` and `tracker.ex`
— the `CourseSite` subsystem has no processes.

- **`init/1` does no I/O and cannot fail**, so a missing or broken course
  directory never stops the application booting; the first build runs from
  `handle_continue`.
- It watches the course directory and the progress file's directory with
  `FileSystem`. `rebuild?/2` is the pure half and the only decision the process
  makes: `collections/`, `_includes/`, `_data/`, `favicons/`, `index.md`,
  `favicon.ico` and the progress file rebuild; everything else in `course/` —
  the asset sources, the Ruby bundle's cache, the generated PDFs — does not.
- It debounces, then builds **synchronously**, with `output: :swap`. A failed
  build logs and leaves the previous output in place, so the development server
  keeps serving the last good build — which is the argument for staging over
  building in place.
- `rebuild/0` forces one from IEx and from the tests.
- `{:file_system, "~> 1.0"}` becomes a plain runtime dependency. It is already
  in `mix.lock`, but only through `phoenix_live_reload` (`only: :dev`), so
  naming it from `lib/` would warn at compile time and fail in `:prod`.
- [`Application`](../app/lib/archidep/application.ex) starts it only when a build
  directory is configured — a runtime `Application.get_env` gate, the way
  `dns_cluster_query` is read there. Not an environment check: the gate is the
  absence of anywhere to write.

## The endpoint, the configuration and one small plug

Configuration extends the existing `course_site:` block of `config.exs`, already
the one home for what this deployment's course site is, with `build_dir` and
`course_dir`; `dev.exs` sets them. The progress file and the static directory are
**not** new configuration — they have homes in `ReadCourseSessions.progress_file/0`
and `Application.app_dir/2`. Nothing is set in test or production, so nothing
starts and nothing is served there.

[`Endpoint`](../app/lib/archidep_web/endpoint.ex) gains a `@course_site_dir`
compile-time attribute beside `@serve_static`, and its pipeline is reshaped:

| Plug                          | Why it is where it is                                              |
| ----------------------------- | ------------------------------------------------------------------ |
| `Phoenix.LiveReloader`        | moved up: its `before_send` must be registered before the response |
| `Plug.Static.IndexHtml`       | unchanged; one instance serves all three plugs below it            |
| `ArchiDepWeb.CourseSitePages` | development only — see below                                       |
| `Plug.Static` (the build)     | no `:only` — a build owns its output directory                     |
| `Plug.Static` (`priv/static`) | the whitelist, unchanged                                           |
| `Phoenix.CodeReloader`        | stays after, so serving a file still never recompiles              |

The build is consulted first, so it wins `/`, `/course/…`, `/cheatsheets/…`,
`/favicon.ico` and `/404.html`, while `priv/static` answers `/assets/**`,
`/lunr.json`, `/search.json` and `/feed.xml` behind it. Jekyll writing the same
paths into `priv/static` stops mattering because those paths are never asked of
it. `ArchiDepWeb.static_paths/0` is **not** touched: it is the whitelist for
`priv/static` and it also feeds `VerifiedRoutes`, and trimming it is
[cutover](./death-of-jekyll.md#cutover)'s business.

`ArchiDepWeb.CourseSitePages` is new, about 25 lines, and exists for one reason:
a `Plug.Static` response cannot carry the live-reload script. It answers a
`GET`/`HEAD` whose path ends in `.html` by reading the file and sending it as a
body, which the live reloader can then inject into; anything else, and any read
failure, passes through untouched. `Path.safe_relative/1` refuses a traversal.

**Reloading the browser** takes a marker: the watcher touches
`app/tmp/course_site.reload` after a successful swap, and a
`~r"tmp/course_site\.reload$"E` pattern joins the `live_reload` list in
`dev.exs`. A marker rather than the output tree, because the swap is a directory
rename — inotify reports one event and does not descend into it, so the built
files would never be seen. Touching it afterwards also gets the ordering right:
the browser is told when the build is _complete_, not when the edit happened.

## Docker, the host and the documentation

The `app` service of `compose.dev.yml` gains two read-only mounts, `./course`
and `./app/priv/course`, which is what lets it compile at all. **The build output
stays inside the container** at `/archidep/app/tmp/course_site`: it is derived,
writing some 2400 files per rebuild across a macOS bind mount would dominate the
rebuild, and keeping it there stops a containerised watcher from fighting a
host-run build, whose default output is the same path.

Nothing else in the development stack changes yet. The Jekyll `course` service,
its health check and the `app` dependency on it all stay, because Jekyll is still
the only producer of `search.json` and `lunr.json`, which the search dialog
fetches at runtime and which this build does not write.

Documentation, one fact one home:

- [`archidep_web/CONTRIBUTING.md`](../app/lib/archidep_web/CONTRIBUTING.md)
  already says the endpoint serves the static course site from `priv/static`;
  that sentence becomes the new order, and it is the one home for it.
- [`app/CONTRIBUTING.md`](../app/CONTRIBUTING.md) gains one bullet for the
  builder and the watcher.
- [`course_site/CONTRIBUTING.md`](../app/lib/archidep/course_site/CONTRIBUTING.md)
  gains "a build carries the files anchored at its mount point" in _Building_,
  and the swap sentence on the "reading comes before writing" bullet, which
  already anticipates it.
- [`README.md`](../README.md) gains one sentence in each of the two workflows.
- This document records the corrections; the backlog item stays unchecked.
- `npm run lint:md` afterwards.

---

## Tests

Following the [testing conventions](../app/docs/testing.md). Every assertion
below is a whole-value `==`; none is partial.

- **`build_test.exs`** — `site_fixture/1` writes the ten root files and the
  existing whole-`%Site.Inputs{}` equality assertion covers them, which is also
  what pins the list. New: one file omitted, asserting the whole
  `{:error, [{:unreadable_source, …}]}`, and two omitted, asserting both entries.
  A new `describe "swap_output/2"`: a fresh output, an output holding an earlier
  build (asserting the whole directory by `==` — the old files must be _gone_,
  which is the point), a stale `.old` left behind, and a missing staging
  directory.
- **`site_test.exs`** — the private `inputs/1` helper gains `root_files`
  defaulting to `%{}`, so every existing whole-`files` assertion still passes;
  one new test asserts a plan's `files` whole, with a root file beside the three
  build files and the pages.
- **`course_site/builder_test.exs`** (new) — a happy path over a minimal course
  written inline, asserting `{:ok, %Report{…}}` whole and the written directory
  whole; one test per failing stage asserting the whole `{:error, what, errors}`;
  and a `:swap` test proving a failed build leaves the previous output untouched.
- **`course_site_watcher_test.exs`** (new) — started with `start_supervised!`
  and a stub builder passed on `start_link`, since a `Hammox` mock cannot serve a
  process the test does not own. It pins the first build's whole option list, a
  `collections/` event rebuilding and a `node_modules/` one not, two events
  inside the debounce window producing exactly one build, and a failed build
  leaving the process alive — observed with a synchronous call rather than a
  sleep. `rebuild?/2` gets its own `describe`.
- **`course_site_pages_test.exs`** (new) — the plug driven directly with
  `Plug.Test.conn/2`, asserting a whole `%{status:, content_type:, body:,
halted:}` projection by `==` for an existing page, a path that is not HTML, a
  missing file and a traversal attempt. This is a **documented departure** from
  the rule that [plugs are tested through a
  route](../app/docs/testing.md#plumbing-router-plugs-auth): the plug is gated by
  a compile-time attribute and `serve_static` is false in test, so no route can
  reach it. **Explicitly authorised, 2026-08-01.**

Two things are **not** testable and get said in the commit message rather than
covered by a test that asserts nothing: the endpoint's plug **ordering** (both
gates are `compile_env` and `serve_static` is false in test, so no request can
reach them without recompiling the endpoint), and the live-reload chain end to
end, three of whose four hops are in a dependency — the watcher test covers the
one hop that is ours, that a successful build touches the marker.

## Verification

1. `mix archidep.course_site.build --clean --undigested` succeeds and
   `app/tmp/course_site` now holds `favicon.ico` and `favicons/`. **Time it** —
   that is the per-edit cost of the watcher.
2. `mix format`, `mix credo --strict`, `mix test`, and `mix dialyzer` last.
3. On the host: the asset watchers, Jekyll and `mix phx.server`; then walk the
   site — the home page and its three cards, a subject, an exercise, a
   cheatsheet, a deck, `/404.html` — looking at what only a browser shows:
   `lumis` colours, mermaid, reveal.js, the emoji images, the sidebar's progress
   borders, the "on this page" navigation, the favicon.
4. Edit a document: the log shows a rebuild and the browser reloads by itself.
5. Break one (a dangling `{% link %}`): the log shows every error and the
   browser still serves the previous good build.
6. In Docker, `./scripts/dev` from a clean `tmp/docker`: the `app` container
   compiles — which it cannot today — and serves the same pages.
7. `/assets/**` and the search dialog still work, i.e. the fall-through to
   `priv/static` is live.

## Risks and what this leaves open

- **The rebuild cost is the main risk.** Every build hashes and copies all 373
  files that sit next to a page — 49 MB — because a staging directory starts
  empty by design. That is fine on an SSD and possibly unpleasant through a
  Docker bind mount. Measure it before optimising anything; hard-linking, or
  carrying the previous build's asset tree over when the content tree's file set
  is unchanged, are the candidates, and neither belongs in this item.
- **Jekyll must keep running in development**, for `search.json`, `lunr.json`
  and `feed.xml`. That puts the [search index](./death-of-jekyll.md#search-index)
  on the critical path to deleting Jekyll.
- **A newly added global asset** — a new emoji, a new stylesheet — is only
  picked up on the next rebuild, since the watcher ignores `priv/static/assets`,
  which churns constantly. `CourseSiteWatcher.rebuild()` covers it.
- **On the host the first build fails** if the asset watchers have not yet
  written `priv/static/assets`. Log it clearly once; no retry logic. Docker
  cannot hit this, its health checks already gating startup.
- **A `{:root_file, _}` reference is still unchecked**: an eleventh one added to
  the chrome without a matching entry publishes a broken image and no error. The
  `UrlContext` root-file manifest is the fix, deferred.
- **Root files under a version prefix** — `Urls` anchors them at `base_path`
  while the build writes them at the output root, which is the wrinkle
  `/404.html` already has. The [optional URL
  prefix](./death-of-jekyll.md#optional-url-prefix) has to settle both together;
  it is not papered over here.
