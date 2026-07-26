# A richer Course.Material model

An approved implementation plan for one item of the [death of
Jekyll](./death-of-jekyll.md) backlog: **"Keep and strengthen
`ArchiDep.Course.Material` into a typed, compile-checked model of the
course."**

> **This document is temporary.** When the work below is done, tick the
> corresponding checkbox in [`death-of-jekyll.md`](./death-of-jekyll.md#backlog),
> record what changed in that document's own **"Corrections while implementing"**
> notes under [A richer Course.Material
> model](./death-of-jekyll.md#a-richer-coursematerial-model), and **delete this
> file**. It is a plan, not a record; `death-of-jekyll.md` is the record.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Context](#context)
  - [Decisions already taken](#decisions-already-taken)
  - [Measured facts this plan rests on](#measured-facts-this-plan-rests-on)
- [What to build](#what-to-build)
  - [New functions on ArchiDep.CourseSite.Build](#new-functions-on-archidepcoursesitebuild)
  - [New lookups on ArchiDep.CourseSite.Structure](#new-lookups-on-archidepcoursesitestructure)
  - [The compiled model](#the-compiled-model)
  - [Resolving references in the web layer](#resolving-references-in-the-web-layer)
  - [The progress seam](#the-progress-seam)
  - [The sidebar and the other callers](#the-sidebar-and-the-other-callers)
  - [The Docker build](#the-docker-build)
- [Tests](#tests)
- [Documentation](#documentation)
- [Sequencing](#sequencing)
- [Verification](#verification)

<!-- END doctoc -->

---

## Context

The [death-of-jekyll backlog](./death-of-jekyll.md#backlog) has reached its last
structural item. Everything it needs now exists.
[`Structure`](../app/lib/archidep/course_site/structure.ex) works out what the
course is from the content directory,
[`Build`](../app/lib/archidep/course_site/build.ex) fetches the bytes,
[`DocumentRef`](../app/lib/archidep/course_site/document_ref.ex) /
[`PageRef`](../app/lib/archidep/course_site/page_ref.ex) are the identities, and
[`Urls`](../app/lib/archidep/course_site/urls.ex) is the one place a URL is
built.

Meanwhile [`Material`](../app/lib/archidep/course/material.ex) still reads
`priv/static/archidep.json` — a Jekyll build artifact — through
[`MaterialHelpers`](../app/lib/archidep/course/helpers/material_helpers.ex), and
hands the web layer **raw string-keyed maps with URLs baked into them**. So
today:

- the app cannot compile without a Jekyll build having run first;
- `layouts.ex` indexes `section["docs"]`, `item["course_type"]`,
  `cheatsheet["sidebar_title"]` — every one a typo away from a blank entry, none
  of them checked;
- the URLs are strings from JSON, so the version prefix the later tasks
  introduce could never reach them;
- neither module has a single test, and `MaterialHelpers`' 115 uncovered lines
  are an explicit deferral in [`future-work.md`](../app/docs/future-work.md).

**Outcome:** the model is compiled from the Markdown sources into structs,
stores references rather than URLs, resolves those references through the
existing seam at render time, and fails compilation when a reference goes stale.
`archidep.json` stops being a compile-time input of the application — it stays a
build output for `pdf.ts`.

### Decisions already taken

1. **The module moves to `ArchiDep.CourseSite.Material`.** All of its inputs
   live in that namespace; it owns no table, has no use case, policy or event,
   and — the sharpest argument — it **bypasses the facade and therefore
   `Course.ContextMock`**, a permanent hole in the web-layer rule that every
   context is replaced by its mock.
   [`course/CONTRIBUTING.md`](../app/lib/archidep/course/CONTRIBUTING.md) already
   has to call it "not part of the standard anatomy". Moving it also deletes a
   real dependency edge: `ArchiDep.Course`, a stateful context, today
   compile-depends on `../course/collections` being on disk.
2. **Status stays out of the compiled model, but the sidebar keeps it.** A
   narrow progress seam lands here with one implementation.
3. **Headings stay the next task.** The model is shaped so they slot in without
   reshaping it.

### Measured facts this plan rests on

Established by running against the real corpus (63 documents, 960 KB of
Markdown, 425 files under the two content roots), not assumed:

- **`@external_resource` already catches a file being _deleted_** in Elixir 1.19
  (`Mix.Compilers.Elixir.stale_external?/2` treats a `{0, 0}` stat as stale) and
  compares a **content digest** rather than the mtime, so it is immune to CI's
  fresh checkouts. The only gap left for `__mix_recompile__?/0` is a file being
  **added**. This is narrower than the backlog text assumes.
- **Compile cost is ~305 ms**, of which `Build.sources/2` is 261 ms; the
  recompile hook is one directory walk at **16 ms**, against
  `ArchiDep.Git.__mix_recompile__?/0`'s **25 ms** of `git` subprocesses that
  already run on every code-reloaded request today.
- **The corpus is currently `done` everywhere and every section `open: false`.**
  So the sidebar's rendering must come out **byte-identical** after the progress
  work below — a free oracle.
- **`course-section-*` / `course-item-*`
  ([`theme/src/course.css`](../theme/src/course.css) L268-296) are scoped to
  `#course-material-menu`**, which exists only in `layouts.ex`. They are the
  dashboard sidebar's alone.
- **[`theme/src/theme.css`](../theme/src/theme.css) L16-20** safelists the
  `peer/section-*` classes and `@source`s `app/lib/archidep_web` wholesale, so
  moving the sidebar markup to another file under `archidep_web/` needs **no
  theme change**.
- **No existing test asserts any course-material URL**, so the caller migration
  is unguarded until the new tests land.
- Values the tests will need verbatim: chapter 402 is `"Run your own virtual
server on Microsoft Azure"`, not graded, no deck; the sysadmin cheatsheet is
  `"System Administation Cheatsheet"` (the typo is in the content) with
  `sidebar_title` `"System Administration"`.

---

## What to build

### New functions on ArchiDep.CourseSite.Build

`Build` is the one module of the subsystem allowed to touch a file, so the
compile-time read belongs there rather than in a new module beside `Material`.

```elixir
@spec content_files(Path.t()) :: [String.t()]
@spec content_digest(Path.t()) :: binary()
@spec course!(Path.t(), Path.t()) :: Structure.t()
@spec progress_entries!(Path.t()) :: [map()]
```

- `content_files/1` — every file of a content directory, relative to it, sorted.
  `content_tree/1` is refactored to
  `content_dir |> content_files() |> ContentTree.plan()`, which is what makes the
  digest and the tree agree by construction.
- `content_digest/1` —
  `:crypto.hash(:sha256, Enum.join(content_files(dir), "\n"))`. It digests
  **all** content files, not only the Markdown, because `ContentTree.plan/1`
  validates page assets too (`:unsafe_name`, `:duplicate_output_path`), so an
  added image genuinely decides whether `Material` compiles. The price is a
  one-module recompile when an image lands.
- `course!/2` — chains
  `content_tree/1 → sources/2 → declarations/1 → Structure.plan/3`, exactly as
  [`mix archidep.course_site.structure`](../app/lib/mix/tasks/archidep/course_site/structure.ex)
  does, and raises with **every** problem formatted through
  `Build.format_error/1` or `Structure.format_error/1` — the module's existing
  report-everything rule, so a bad content directory is one compile failure
  rather than a run per mistake.
- `progress_entries!/1` — the front matter of `collections/_progress/*.md`, in
  filename order. `ContentTree.roots/0` covers `_course` and `_cheatsheets`
  only, so this is a read of its own; it belongs here for the same reason the
  others do.

**Keep `sources/2` (the full parse) rather than adding a front-matter-only
reader.** It is 261 ms of the 305, dominated by `Source.parse/1` scanning bodies
`Structure` never looks at — but `front_matter/1` exists precisely to project
it, it is the tested path, and a second front-matter parser is a second thing to
keep in agreement with `Source.parse/1` forever. The heading task needs the
bodies anyway.

### New lookups on ArchiDep.CourseSite.Structure

```elixir
@spec fetch_chapter(t(), pos_integer(), String.t()) :: {:ok, Chapter.t()} | :error
@spec chapter!(t(), pos_integer(), String.t()) :: Chapter.t()
@spec cheatsheet!(t(), String.t()) :: Cheatsheet.t()
```

The existing `fetch_chapter/2` (by number alone) stays. The **three**-argument
form is what makes a _rename_ fail: today's `MaterialHelpers.course_document/2`
matched on `num` **and** `course_slug`, and the typed replacement must be no
weaker.

It deliberately does **not** pin the page type. A subject and an exercise are
published at the same URL by design, so requiring `:exercise` would fail a
content change that cannot break the link. Say so in the `@doc` — it is the
first thing a reader will wonder about a function named for an exercise.

### The compiled model

New: `app/lib/archidep/course_site/material.ex`. It reads nothing itself; it
calls `Build`, so `Build` stays the only module that touches the filesystem.
What it _is_, and the one honest amendment to the subsystem's purity claim, is
the subsystem's single **edition-bound** value: everything else is a function of
its inputs, and `Material` is one particular set of inputs, baked.

```elixir
@course_dir Path.expand("../../../../course", __DIR__)          # <repo>/course
@content_dir Path.join(@course_dir, "collections")
@declarations_file Path.join(@course_dir, "_data/course.yml")

@external_resource @declarations_file
for file <- Build.content_files(@content_dir), String.ends_with?(file, ".md") do
  @external_resource Path.join(@content_dir, file)
end

@content_digest Build.content_digest(@content_dir)
@structure Build.course!(@content_dir, @declarations_file)
@sections @structure.sections
@cheatsheets @structure.cheatsheets
@run_virtual_server_exercise Structure.chapter!(@structure, 402, "run-virtual-server")
@sysadmin_cheatsheet Structure.cheatsheet!(@structure, "sysadmin")
```

```elixir
@spec structure() :: Structure.t()
@spec sections() :: [Section.t()]
@spec cheatsheets() :: [Cheatsheet.t()]
@spec run_virtual_server_exercise() :: Chapter.t()
@spec sysadmin_cheatsheet() :: Cheatsheet.t()
@spec __mix_recompile__?() :: boolean()   # @content_digest != Build.content_digest(@content_dir)
```

Four points on the mechanics:

- **A named reference is a module attribute resolved at compile time, not a
  macro.** The callers are `.heex` templates, where a macro would need a
  `require` and would move the failure from one declaration to twelve call
  sites. The raise happens while `Material` compiles — that _is_ the
  compile-fail guarantee.
- **`@sections @structure.sections` rather than a function body** — an attribute
  expression may read another attribute, so the projection happens once instead
  of a map access on a 2298-word literal per call.
- **Only the `.md` files are `@external_resource`s.** Registering 49 MB of
  images would make Mix digest them on every compile; their _names_ are what
  `Material` depends on, and `@content_digest` covers those.
- **No `Application.compile_env` knob for the content directory.** The Dockerfile
  copies to the expected location instead. An unused knob is a smell; add one
  when an archive build actually needs it. `Path.expand(..., __DIR__)` stays in
  `Material` rather than moving to `Build`, because in a release it names a path
  that no longer exists.

**Delete:** `app/lib/archidep/course/material.ex` and
`app/lib/archidep/course/helpers/material_helpers.ex` (its sole caller was
`material.ex`; the `{data, file}` source parameter existed only for a test never
written).

### Resolving references in the web layer

New: `app/lib/archidep_web/helpers/course_material_helpers.ex` —
`ArchiDepWeb.Helpers.CourseMaterialHelpers`, matching the existing
`*_helpers.ex` convention, imported from `html_helpers/0` in
[`archidep_web.ex`](../app/lib/archidep_web.ex) beside `DateFormatHelpers` so it
is available in every template.

```elixir
@spec course_url(Chapter.t() | Cheatsheet.t() | Urls.logical_reference()) :: String.t()
@spec course_url(Chapter.t() | Cheatsheet.t(), String.t()) :: String.t()
@spec url_context() :: UrlContext.t()
```

`%Chapter{page: document}` → `{:document, document}`; `%Cheatsheet{slug: slug}`
→ `{:cheatsheet, slug}`; each wrapped in `{:heading, page, id}` when a heading is
given; anything else passed straight through, so `:home` and friends work.
`Urls.resolve!/2` is the right form here per
[`course_site/CONTRIBUTING.md`](../app/lib/archidep/course_site/CONTRIBUTING.md):
an unresolvable reference in the application's own navigation is a programmer
error.

`heading_url` folds into `course_url/2` rather than being its own function; the
[heading task](./death-of-jekyll.md#heading-references-that-compile-fail) turns
that second argument from a string into a heading value.

**Configuration.** In `config/config.exs`, beside the existing `:auth` /
`:monitoring` / `:servers` groups — an atom key, since there is no
`ArchiDep.CourseSite` module:

```elixir
config :archidep, :course_site, mode: :live, base_path: "", version: nil
```

`url_context/0` reads it with `Application.get_env/3` and builds
`UrlContext.new(mode: …, base_path: …, version: …, build_id: "app")`.

- **`build_id` is the literal `"app"`.** `UrlContext.new/1` requires a non-empty
  string, and the application resolves no `{:build_file, _}` reference, so it has
  nothing meaningful to put there. **Not** `ArchiDep.Git.git_revision/0` — its
  spec is `String.t() | nil`, so it would raise on a checkout where the revision
  cannot be read. Worth a follow-up note that `build_id` could become optional
  with `{:build_file, _}` returning `{:error, {:missing_build_id, _}}`.
- **`version: nil` is what keeps URLs unprefixed.** `content_prefix` is `""`, so
  `{:document, DocumentRef.new(402, "run-virtual-server", :exercise)}` →
  `/course/402-run-virtual-server/` and `{:cheatsheet, "sysadmin"}` →
  `/cheatsheets/sysadmin/` — byte-identical to today. The year arrives with the
  [optional URL prefix](./death-of-jekyll.md#optional-url-prefix) task.
- **Built per call, not memoized.** `UrlContext.new/1` is a dozen guards and
  three empty-map structs; the sidebar's ~54 resolutions cost less than
  rendering 54 `<li>` elements. The natural moment to memoize is the year-prefix
  task, which also has to teach `ArchiDepWeb.static_paths/0` the year segment
  through `Application.compile_env`.
- **No `runtime.exs` wiring now.** `Application.get_env` at request time _is_ the
  runtime seam; only its source changes later.

### The progress seam

New: `app/lib/archidep/course_site/progress.ex` — `ArchiDep.CourseSite.Progress`

```elixir
@type status :: :done | :due | :next | :future
@spec new([map()]) :: t()
@spec status(t(), pos_integer()) :: status()
@spec statuses(t(), Structure.t()) :: %{pos_integer() => status()}
@spec section_open?(t(), Section.t()) :: boolean()
```

The port of the aggregation in
[`course/_plugins/archidep.rb`](../course/_plugins/archidep.rb) (L37-49 and
L142-156), with its two rules carried over deliberately:

- the lists are the **union** of every progress entry with later categories
  subtracted (`due` minus `done`, `next` minus both);
- a section is **open** when its own number is `next`, or any of its chapters is
  neither `done` nor `future`.

**The numbers mix chapters and sections in one lookup.** The Ruby looks a
section up by its own number (100, 200, …) in the same lists that carry chapter
numbers (101, 402, …) — the first progress entry lists `100` precisely for that.
`status/2` must stay one lookup, not two lists.

The three home-page lists (`previously` / `due next` / `next time`) read the
**last** entry carrying each key rather than the union. They belong to the
progress task; they are named here only so the difference is not mistaken for a
bug when someone reads the Ruby.

**Where its numbers come from now:** `Build.progress_entries!/1`, read while
`Material` compiles and registered as `@external_resource`s alongside the
content, since the release has no `course/` directory at runtime. The **call
site stays a render-time call** taking the statuses as data — that is the half
that has to be right for the later swap, and it is what makes the component's
four status branches drivable in a test.

Because the corpus is `done` everywhere today, this must render **identically**
to the current sidebar. That is the verification oracle, not a coincidence to
rely on.

### The sidebar and the other callers

Move the `#course-material-menu` block —
[`layouts.ex`](../app/lib/archidep_web/components/layouts.ex) L212-307 — into a
function component `course_material_menu/1` in
[`course_components.ex`](../app/lib/archidep_web/components/course_components.ex),
with `attr :structure, Structure` and `attr :progress, :map`. `layouts.ex` keeps
one line.

A component rather than inline markup is the only way to drive the sidebar's
branches — deck-only chapter, graded exercise, chapter with a deck beside it,
cheatsheet with and without a `sidebar_title`, all four statuses — from a test.
Through `layouts.ex` they are fixed by the real corpus, which is exactly the
escape hatch [`testing.md`](../app/docs/testing.md) names for testing a
component in isolation.

The field mapping is one for one:

| today                                        | typed                                                                                                                      |
| -------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `section["title"]` / `["slug"]`              | `section.title` / `Section.slug(section)`                                                                                  |
| `section["progress"]`                        | `progress[Section.num(section)]`                                                                                           |
| `section["open"]`                            | `Progress.section_open?(progress, section)`                                                                                |
| `section["docs"]`                            | `section.chapters` — **and the Jekyll rule that filtered a chapter's deck back out disappears**, a chapter being one entry |
| `item["url"]`                                | `course_url(chapter)`                                                                                                      |
| `item["course_type"]`                        | `chapter.page.type`                                                                                                        |
| `item["graded"] == true`                     | `chapter.graded?`                                                                                                          |
| `item["slides"]`                             | `Chapter.slides?(chapter)`                                                                                                 |
| `item["progress"]`                           | `progress[Chapter.num(chapter)]`                                                                                           |
| `cheatsheet["sidebar_title"] \|\| ["title"]` | `Cheatsheet.sidebar_title(cheatsheet)`                                                                                     |

The `Enum.with_index/1` stays — the `peer/section-#{i}` classes need it. And
`target="_target"` at L255 becomes `target="_blank"`: `_target` is not a browser
keyword, it names a window literally called `_target`, so every slides link
shares one. A deliberate behaviour fix riding along, called out in review.

The rest are mechanical, and every URL they produce is the one produced today:

- [`server_help_component.ex`](../app/lib/archidep_web/servers/server_help_component.ex)
  — 11 sites of `Material.run_virtual_server_exercise().url <> "#anchor"` become
  `course_url(Material.run_virtual_server_exercise(), "create-your-server")`; the
  bare one at L198 drops the second argument.
- [`dashboard_live.html.heex`](../app/lib/archidep_web/dashboard/dashboard_live.html.heex)
  L145/148/171/209 and
  [`new_server_dialog_live.html.heex`](../app/lib/archidep_web/servers/new_server_dialog_live.html.heex)
  L33/37 — `.url` → `course_url(…)`. `.title` needs **no** change:
  `Chapter.title` is the same field name the old map used.
- [`change_username_dialog_live.html.heex`](../app/lib/archidep_web/course/change_username_dialog_live.html.heex)
  L82 →
  `course_url(Material.sysadmin_cheatsheet(), "how-do-i-change-my-username-usermod")`.
- The four `.ex` modules swap `alias ArchiDep.Course.Material` for
  `alias ArchiDep.CourseSite.Material`.

### The Docker build

[`Dockerfile`](../Dockerfile) L223 copies `archidep.json` out of the Jekyll stage
so the application can compile. That line goes. `WORKDIR` is `/usr/src/app` and
`./app/` is copied there, so the repository root maps to `/usr/src` and
`Path.expand("../../../../course", __DIR__)` resolves to `/usr/src/course`.
After L222, before `mix sentry.package_source_code && mix release` at L234:

```dockerfile
COPY --chown=app:app ./course/collections/ /usr/src/course/collections/
COPY --chown=app:app ./course/_data/course.yml /usr/src/course/_data/course.yml
```

`course/collections` is 49 MB, so this is a fat layer — in a stage that is
discarded, since only `_build/prod/rel/archidep` reaches the final image.
Copying only the Markdown would satisfy `Structure` but not `ContentTree`'s
page-asset validation, and Docker cannot glob by extension recursively.

The Jekyll stage keeps writing `archidep.json` into `priv/static` at L232 for
`pdf.ts` — it is now a build output only, the decision [Drop the archidep.json
round-trip?](./death-of-jekyll.md#drop-the-archidepjson-round-trip) already
recorded. This **reverses a build-order dependency**: the application no longer
needs Jekyll to have run in order to compile.

**CI needs no change.** `actions/checkout` takes the whole repository and every
app step runs with `working-directory: app`, so `../course/collections` is
always there. Worth noting as a follow-up (out of scope): `build-app` depends on
`build-course` only for the static artifact, and that edge could now be relaxed.

---

## Tests

Strictly per [`app/docs/testing.md`](../app/docs/testing.md). The brittleness
problem is solved by putting **every assertable rule on synthetic data** and
leaving the real corpus only where a change to it genuinely must break a test.

- **`test/archidep/course_site/build_test.exs`** (extend, `async: true` with
  `:tmp_dir` as its existing blocks do) — `content_files/1`: the whole sorted
  list by `==`, covering a dotfile, a file outside the two roots and a directory.
  `content_digest/1`: `==` a hash the test computes independently (a true oracle,
  not `digest(dir) == digest(dir)`), then `refute` equality after adding a file
  and after removing one. `course!/2`: the whole `%Structure{}` by `==` against a
  hand-built one, and the **raised message** by `==` at each of the four failing
  stages, which is what pins "every problem is in the one message".
  `progress_entries!/1`: the whole list by `==`.
- **`test/archidep/course_site/structure_test.exs`** (extend) —
  `fetch_chapter/3` found, right number with wrong slug → `:error`, unknown
  number → `:error`; `chapter!/3` and `cheatsheet!/2` return the value on a hit
  and raise an exact message on a miss.
- **`test/archidep/course_site/progress_test.exs`** (new) — `new/1` and
  `status/2` over synthetic entries: a chapter listed in more than one category,
  a section number in the same list as chapter numbers, a number in none.
  `section_open?/2` once per branch of the Ruby's rule. `statuses/2` as a whole
  map by `==`.
- **`test/archidep/course_site/material_test.exs`** (new, plain
  `ExUnit.Case, async: true`) — the module compiles from the real corpus, so this
  asserts facts about the **module** plus the two corpus facts the dashboard's
  prose depends on: `sections/0` and `cheatsheets/0` `==` the corresponding
  fields of `structure/0` (which would catch a `sections/0` that sorted or
  filtered); `run_virtual_server_exercise/0` `==` the whole `%Chapter{}` written
  by hand; `sysadmin_cheatsheet/0` `==` the whole `%Cheatsheet{}`; and
  `refute Material.__mix_recompile__?()`, a real oracle that fails if the digest
  is non-deterministic or reads the wrong directory.

  **Deliberately not asserted:** the whole `%Structure{}` of the real corpus. A
  50-chapter literal would break on every syllabus edit made by a course author
  who is not touching Elixir — the "trains everyone to update assertions blindly"
  failure mode the testing guide warns about. What the corpus must satisfy is
  already refused by `Structure.plan/3` and checked by
  `mix archidep.course_site.structure`.

- **`test/archidep_web/components/course_components_test.exs`** (extend) —
  `course_material_menu/1` over a **synthetic** structure and status map,
  asserted as **one whole projection by `==`** covering every region at once: per
  section its title, slug, status, fold state and chevrons; per chapter its
  title, `href` (a literal, a genuine oracle for the `Urls` wiring), target, icon
  and status; per cheatsheet its listed name and `href`. `icon` and `status` are
  projected to **semantic values** (`:graded_exercise`, `:has_slides`, `:done`)
  rather than pinning emoji markup or class strings. Cover each branch and assert
  the **absence** of the deck badge and the external-link icon where they must
  not render.
- **`test/archidep_web/components/layouts_test.exs`** — the eight existing tests
  keep `material_menu?: true` unchanged. That field is normally the free-floating
  boolean [`AGENTS.md`](../AGENTS.md) flags, and the reason it stands here goes
  in the review note rather than being skipped silently: the region's content is
  now a separate component with a whole-value test of its own, the field has no
  meaningful variants to distinguish, and the only stronger assertion available
  either hardcodes the syllabus a second time or derives its expectation from
  `Material` — a tautology with respect to the model.
- **Web caller tests** — none currently asserts a material URL, so none _must_
  change. If the wiring is worth pinning, the natural place is one field in each
  page's existing projection carrying the exercise link's `href` as a literal.
- **Coverage** — `coveralls.json` floors at 93%. `MaterialHelpers`' 115
  uncovered lines leave the denominator and the new code is covered, so the
  number should go up.

**Before reporting the work done**, run the diff self-audit
[`AGENTS.md`](../AGENTS.md) requires: classify every added assertion, and re-read
every added comment against the comment rules (no reference to `wip/`, no
restatement of the testing guidelines, no historical rationale).

---

## Documentation

- **[`app/lib/archidep/course_site/CONTRIBUTING.md`](../app/lib/archidep/course_site/CONTRIBUTING.md)**
  — rewrite "Why this is not a bounded context" (L69-73): the relationship to
  `Course` is gone; state instead that `Material` is the subsystem's one
  edition-bound value. Add a section under "What the course is" covering: why it
  is compiled; that it stores references and the application resolves them; that
  the recompile trigger is `@external_resource` for what a file _says_ plus a
  digest of the directory for what it _holds_, and why neither covers the other's
  case; why a named reference matches on number and slug but not on type; where
  the URL context comes from. Update the `Build` table (L305-310), the "A page is
  read once" paragraph, and the Testing section. Re-run doctoc.
- **[`app/lib/archidep/course/CONTRIBUTING.md`](../app/lib/archidep/course/CONTRIBUTING.md)**
  — remove the Overview bullet (L54-56), the Context Structure bullet (L83-85)
  and the whole "Course Material Integration" section (L216-231) with its TOC
  entry, leaving one sentence pointing at the course-site document. Re-run
  doctoc. Keep it structurally consistent with the Accounts template.
- **[`app/lib/archidep_web/CONTRIBUTING.md`](../app/lib/archidep_web/CONTRIBUTING.md)**
  — add `CourseMaterialHelpers` to the helper list (L423-438) and
  `course_material_menu/1` to the `CourseComponents` entry (L383).
- **[`app/CONTRIBUTING.md`](../app/CONTRIBUTING.md)** — the `Course` context
  bullet says "and integration with the course material"; drop that clause.
- **[`AGENTS.md`](../AGENTS.md)** — the course-site entry should mention the
  compiled model the dashboard links into.
- **[`app/docs/future-work.md`](../app/docs/future-work.md)** L468-470 — delete
  the `Course.Helpers.MaterialHelpers` bullet; the module is gone.
- **[`course/CONTRIBUTING.md`](../course/CONTRIBUTING.md)** L757-762 —
  `archidep.json` is described as existing "so that the dashboard application can
  replicate the sidebar"; it is now `pdf.ts`'s artifact alone.
- **Module docs naming the old module** —
  [`document_ref.ex`](../app/lib/archidep/course_site/document_ref.ex) L7 and
  [`structure.ex`](../app/lib/archidep/course_site/structure.ex) L10.
- **[`death-of-jekyll.md`](./death-of-jekyll.md)** — tick the checkbox and write
  the **"Corrections while implementing"** subsection under [A richer
  Course.Material model](./death-of-jekyll.md#a-richer-coursematerial-model), as
  every completed task in that document does: the move and its reasoning; that
  `@external_resource` already catches deletion so the hook only covers
  additions; the measured cost; the `build_id` friction; the `target="_target"`
  fix; the progress interim. Also resolve the deferral recorded under [Consumers
  as configurations](./death-of-jekyll.md#consumers-as-configurations) and the
  paragraph under [The home page
  exception](./death-of-jekyll.md#the-home-page-exception) that says "Keep
  `Course.Material` storing references", and adjust the consequences listed under
  [Drop the archidep.json
  round-trip?](./death-of-jekyll.md#drop-the-archidepjson-round-trip) to record
  what the recompile trigger actually became. **Then delete this file.**
- `npm run lint:md` after all of it.

---

## Sequencing

Six reviewable steps, each compiling and green on its own:

1. `Build.content_files/1`, `content_digest/1`, `course!/2`,
   `progress_entries!/1` + `Structure.fetch_chapter/3`, `chapter!/3`,
   `cheatsheet!/2`, with their tests. Nothing else moves.
2. `ArchiDep.CourseSite.Material` + its test. `Course.Material` still exists and
   still works — the two coexist for one commit, which is what makes the URL
   parity check below possible.
3. `CourseMaterialHelpers` + the `:course_site` config + the `html_helpers/0`
   import + its test.
4. `ArchiDep.CourseSite.Progress` + its test.
5. The callers: `course_material_menu/1` and its test, `layouts.ex`, the five
   other call sites. Delete `Course.Material` and `MaterialHelpers`.
6. Dockerfile, documentation, the backlog checkbox, deleting this file.

---

## Verification

From `app/` unless noted.

```sh
mix compile --force                     # the model compiles from Markdown
mix archidep.course_site.structure      # the real content is still a course

# archidep.json is no longer a compile-time input
mv priv/static/archidep.json /tmp/ && mix compile --force && mv /tmp/archidep.json priv/static/

mix test test/archidep/course_site test/archidep_web
mix test --repeat-until-failure 3
mix check                               # coveralls --raise, format, credo --strict, dialyzer
cd .. && npm run lint:md
docker build --target release .
```

**URL parity — the fidelity gate for this change.** With both models present
(after step 2), a `mix run` script compares every chapter and cheatsheet URL
`course_url/1` emits against the `url` field of the checked-in `archidep.json`,
sorted, by `==`. Both lists must be identical; the version prefix is a later
task.

**Manual checks that mutate the working tree** — run each, then `git checkout`:

- **A stale reference is a compile error.**
  `git mv course/collections/_course/402-run-virtual-server{,-renamed}` then
  `mix compile` → the raise from `Structure.chapter!/3` naming 402 and the slug.
- **An edit recompiles** (the `@external_resource` digest path): append a space
  to `402-run-virtual-server/exercise.md`.
- **An addition recompiles** (the `content_digest` path): `touch
402-run-virtual-server/notes.md` — and correctly _fails_, since `ContentTree`
  refuses an unknown Markdown source.
- **A removal recompiles** (`@external_resource`'s missing-file branch): delete a
  `slides.md`.

**The rendered result.** Start the app and compare the sidebar against
production: same sections in the same order, same entries and icons, same
`done`/`due`/`next` colouring, same folds, same URLs — the corpus is `done`
everywhere today, so anything that differs is a bug in this change. Then the
four other surfaces: the dashboard's "run a virtual server" links, the
new-server dialog, the server help panel's 11 anchors, and the change-username
dialog's cheatsheet anchor.
