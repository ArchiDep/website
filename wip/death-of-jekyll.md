# Elixir-native course rendering

A plan to replace the Jekyll static-site generator (`course/`) with an
Elixir-native rendering step inside the Phoenix application.

**Headline:** This is not "reimplementing Jekyll." The surface this course
actually uses is small and clean, and the codebase is already half-way there.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Backlog](#backlog)
- [Goals and constraints](#goals-and-constraints)
- [Task details](#task-details)
  - [Testing as we go](#testing-as-we-go)
  - [Revisit the Solid (Liquid) library decision](#revisit-the-solid-liquid-library-decision)
  - [Drop the archidep.json round-trip?](#drop-the-archidepjson-round-trip)
  - [Shared Markdown rendering core](#shared-markdown-rendering-core)
  - [Custom block tags](#custom-block-tags)
  - [Progressive solution reveal](#progressive-solution-reveal)
  - [Reference-link resolution](#reference-link-resolution)
  - [TOC and heading anchors](#toc-and-heading-anchors)
  - [Smaller Jekyll plugins](#smaller-jekyll-plugins)
  - [Slides](#slides)
  - [Asset URLs](#asset-urls)
  - [Metadata generation](#metadata-generation)
  - [A richer Course.Material model](#a-richer-coursematerial-model)
  - [Heading references that compile-fail](#heading-references-that-compile-fail)
  - [Static build step](#static-build-step)
  - [Standalone / archival mode](#standalone--archival-mode)
  - [Optional URL prefix](#optional-url-prefix)
  - [Per-year PDF archive](#per-year-pdf-archive)
  - [Search index](#search-index)
  - [HTML fidelity gate](#html-fidelity-gate)
  - [Cutover](#cutover)
- [What the course actually depends on (measured, not assumed)](#what-the-course-actually-depends-on-measured-not-assumed)
- [The decisive point: half of this is already rendered in Elixir](#the-decisive-point-half-of-this-is-already-rendered-in-elixir)
- [What gets simpler, and what is load-bearing](#what-gets-simpler-and-what-is-load-bearing)
- [The honest hard parts / risks](#the-honest-hard-parts--risks)
- [An architectural fork worth deciding early](#an-architectural-fork-worth-deciding-early)
- [Verdict and suggested path](#verdict-and-suggested-path)

<!-- END doctoc -->

---

## Backlog

Concrete, trackable tasks to reach an Elixir-native course renderer that still
produces a fully static build. Each item links to a [Task
details](#task-details) subsection (and, where relevant, to the analysis further
down). Ordered roughly by dependency: decisions first, then the rendering core,
then the static build, then QA and cutover.

**Cross-cutting:** every new module is **unit-tested as we go** (not retrofitted
at the end) — see [Testing as we go](#testing-as-we-go). This plan follows the
now-complete testing plan's conventions in
[`app/docs/testing.md`](../app/docs/testing.md).
We are also going **scorched earth**: the new system _replaces_ Jekyll outright;
we do not maintain both pipelines side by side — see [Goals and
constraints](#goals-and-constraints).

**Decisions to settle first**

- [x] Re-do the analysis of whether the `Solid` (Liquid) library is appropriate.
      **Decided: adopt `Solid`** rather than a hand-rolled preprocessor — see
      [Revisit the Solid (Liquid) library
      decision](#revisit-the-solid-liquid-library-decision).
- [ ] Decide whether the intermediate `archidep.json` can be dropped in favour
      of a shared in-process core — see [Drop the archidep.json
      round-trip?](#drop-the-archidepjson-round-trip).
- [ ] Confirm the static-build-step architecture and defer the runtime mode —
      see [Static build step](#static-build-step) and [An architectural fork worth
      deciding early](#an-architectural-fork-worth-deciding-early).

**Rendering core**

- [ ] Build a shared Markdown-parsing/rendering core (MDEx + AST helpers)
      reusable by both the static build and the Phoenix app — see [Shared Markdown
      rendering core](#shared-markdown-rendering-core).
- [ ] Port the six custom block tags
      (`note`/`callout`/`cols`/`solution`/`mermaid`/`markdown`) as an Elixir
      preprocessor — see [Custom block tags](#custom-block-tags).
- [ ] Reproduce reference-link resolution into extracted tag blocks and slides —
      see [Reference-link resolution](#reference-link-resolution).
- [ ] Generate heading IDs and the "On this page" TOC from the AST — see [TOC
      and heading anchors](#toc-and-heading-anchors).
- [ ] Replace the smaller Jekyll plugins (`jemoji`, `target-blank`, `seo-tag`,
      `feed`) — see [Smaller Jekyll plugins](#smaller-jekyll-plugins).
- [ ] Handle slides with tag/asset preprocessing only (no Markdown→HTML step) —
      see [Slides](#slides).
- [ ] Subsume the asset-digest plumbing via `phx.digest` + verified routes — see
      [Asset URLs](#asset-urls).

**New features (built alongside the migration)**

- [ ] Hide solution blocks by default and reveal them via frontmatter flags as
      the course progresses — see [Progressive solution
      reveal](#progressive-solution-reveal).

**Metadata and the `Course.Material` model**

- [ ] Port the filename→metadata and progress-aggregation logic to deterministic
      Elixir — see [Metadata generation](#metadata-generation).
- [ ] Keep and strengthen `ArchiDep.Course.Material` into a typed,
      compile-checked model of the course — see [A richer Course.Material
      model](#a-richer-coursematerial-model).
- [ ] Make headings first-class so dynamic references compile-fail instead of
      using brittle anchor strings — see [Heading references that
      compile-fail](#heading-references-that-compile-fail).

**Static build, archival and per-year versions**

- [ ] Implement the static build step writing to the same `priv/static` layout
      Jekyll produces — see [Static build step](#static-build-step).
- [ ] Preserve a fully static, dashboard-free standalone/archival output (GitHub
      Pages backup) — see [Standalone / archival mode](#standalone--archival-mode).
- [ ] Support an optional URL prefix (e.g. `/2025-2026/`) for per-year archived
      versions — see [Optional URL prefix](#optional-url-prefix).
- [ ] Decide where per-year generated PDFs are kept alongside the archived site
      — see [Per-year PDF archive](#per-year-pdf-archive).

**Search, QA and cutover**

- [ ] Reuse the existing `npm run idx`/`lunr` path initially, building
      `search.json` with Floki — see [Search index](#search-index).
- [ ] Run an HTML fidelity diff / visual-regression gate against current Jekyll
      output — see [HTML fidelity gate](#html-fidelity-gate).
- [ ] Cut over: delete the Liquid sidebar/header, drop the Ruby/Jekyll stage —
      see [Cutover](#cutover).

---

## Goals and constraints

These are firm decisions that shape every task above. They are recorded here so
the backlog items stay short.

- **A fully static build must remain possible**, exactly as today, with none of
  the dynamic parts (teacher/student UI, cloud-server details, login, etc.).
  This serves two purposes: (1) **archival** of previous years' material, and
  (2) a **backup static copy** (e.g. on GitHub Pages) that students can reach if
  the main server is down. The renderer must therefore stay a plain, reusable
  module — see [Static build step](#static-build-step) and [Standalone /
  archival mode](#standalone--archival-mode).
- **A runtime (dynamic controller/LiveView) rendering mode is explicitly
  deferred.** We keep the door open by structuring the renderer as a plain
  module, but we will not build a runtime mode any time soon. See [An
  architectural fork worth deciding
  early](#an-architectural-fork-worth-deciding-early).
- **Per-year versioning under a URL prefix** is a goal: each year we want to
  save that year's content under a prefix such as `/2025-2026/`, keeping every
  version of the course. Generated PDFs for the year should be archived
  alongside. See [Optional URL prefix](#optional-url-prefix) and [Per-year PDF
  archive](#per-year-pdf-archive).
- **`ArchiDep.Course.Material` must remain a compiled module.** Dynamic parts of
  the Phoenix app reference it, and we _want_ compilation to fail when a
  reference becomes invalid. We additionally want it richer — able to reference
  a specific **heading**, replacing today's brittle anchor strings. See [A
  richer Course.Material model](#a-richer-coursematerial-model) and [Heading
  references that compile-fail](#heading-references-that-compile-fail).
- **The intermediate `archidep.json` is a candidate for removal.** It was
  introduced only so the Elixir app had something to compile against without
  reading raw Jekyll files. Once both the app and the static build share one
  Elixir Markdown core, the round-trip may be unnecessary. To be decided, not
  assumed — see [Drop the archidep.json
  round-trip?](#drop-the-archidepjson-round-trip).
- **The `Solid`-is-not-appropriate conclusion must be re-examined** with a
  proper analysis before we commit to a custom preprocessor. See [Revisit the
  Solid (Liquid) library decision](#revisit-the-solid-liquid-library-decision).
- **Clean replacement, not coexistence (scorched earth).** We will not run the
  Jekyll and Elixir pipelines side by side, nor keep a permanent production
  feature-flag fallback. The only safety net is a **frozen snapshot** of the
  current Jekyll HTML output, captured once as the regression baseline; once the
  new renderer matches it we **delete the entire Jekyll/Ruby toolchain**. Any
  build-time flag is temporary scaffolding for the migration, removed at
  [Cutover](#cutover). See [HTML fidelity gate](#html-fidelity-gate).
- **Everything is unit-tested as we go.** Each new module (renderer, tag
  preprocessor, metadata, `Course.Material`) ships with tests in the same change,
  not as a later pass. This is the cross-cutting working agreement for the whole
  plan and follows the [testing conventions](../app/docs/testing.md). See
  [Testing as we go](#testing-as-we-go).
- **Solutions are hidden until explicitly revealed.** Solution blocks must not
  appear until enabled as the course progresses, driven by frontmatter flags the
  same way `progress` is. This is a new feature built alongside the migration.
  See [Progressive solution reveal](#progressive-solution-reveal).

---

## Task details

Detail for the [Backlog](#backlog). Each subsection fleshes out one or more
checklist items; several cross-reference the analysis above so it stays the
reference record.

### Testing as we go

A cross-cutting requirement, not a single task: **every module lands with unit
tests in the same change.** This is feasible precisely because the renderer is a
plain, web-decoupled Elixir core ([Shared Markdown rendering
core](#shared-markdown-rendering-core)) — pure functions over Markdown/AST are
easy to test in isolation. Concretely:

- **Tag preprocessor** — table tests per tag (`note`/`callout`/`cols`/`solution`/
  `mermaid`/`markdown`): given input Markdown, assert the emitted HTML, including
  edge cases (nested Markdown, `cols`' `<!-- col -->` splitting, `callout`
  unique-ID generation, reference links inside blocks).
- **Metadata generation** — deterministic filename→`num`/`section`/`course_type`/
  `progress` mapping and progress aggregation are pure and should be exhaustively
  unit-tested.
- **`Course.Material`** — assert the typed model and that
  document/heading resolvers exist (the compile-fail guarantee itself is the
  ultimate test, but cover lookups too).
- **Solution visibility** — assert hidden-by-default and reveal-on-flag behaviour
  ([Progressive solution reveal](#progressive-solution-reveal)).
- **Fidelity** — the page-by-page HTML diff against the frozen baseline is a
  separate, coarser gate ([HTML fidelity gate](#html-fidelity-gate)); unit tests
  cover behaviour, the diff covers parity.

Align all of this with the now-complete testing plan's conventions in
[`app/docs/testing.md`](../app/docs/testing.md) and the app's existing
conventions in [`app/CONTRIBUTING.md`](../app/CONTRIBUTING.md).

### Revisit the Solid (Liquid) library decision

**Decision: adopt [`Solid`](https://hex.pm/packages/solid)** (the pure-Elixir
Liquid implementation, v1.3.2), not a hand-rolled preprocessor. This reverses
the earlier dismissal in [The honest hard parts /
risks](#the-honest-hard-parts--risks) (point 2), which was an assumption. The
evidence that flips it, measured against the actual content and the actual
`Solid` source:

- **Block-tag bodies are pure Markdown.** Extracting every
  `note`/`callout`/`cols`/`solution`/`markdown` body and scanning it turns up
  **no** nested tags, `{% include %}`, `{% link %}`, or filters inside them —
  only `:emoji:` shortcodes, which are an emoji-layer concern, not Liquid. So a
  body never needs Liquid re-parsing; it needs **raw capture → MDEx**, which is
  exactly what `Solid`'s built-in `RawTag` already does. The "custom block tags
  with Markdown-inside are fiddly" objection assumed nested Liquid in bodies and
  does not hold.
- **The genuinely fiddly part is the _inline_ Liquid, and that is Liquid's home
  turf.** Content uses `{% link path %}` **×94**, `{% include icons/x.html %}`
  **×44**, `{{ x | relative_file_url }}` **×22**, `{{ page.title }}` ×3, `{%
highlight %}` ×2 — inline output tags and filters. A hand-rolled scanner would
  have to reimplement attribute parsing, quoting, whitespace control (`{%-
-%}`), and filter arguments for these; `Solid` provides them.
- **Highest fidelity to today's Jekyll behaviour.** `Solid` keeps the same
  whole-document-Liquid-then-Markdown model, whitespace control, and attribute
  conventions, which de-risks the [HTML fidelity gate](#html-fidelity-gate) —
  the plan's dominant cost. A hand-rolled preprocessor that is _more_ permissive
  about stray delimiters is a behaviour change during the very gate we must
  pass.
- **Less custom code, on a maintained/tested base.** The implementation is ~6
  thin block-tag structs (a shared raw-body helper, à la `RawTag`, whose
  `render` calls MDEx on the captured body) + 2–3 inline tags + one
  `relative_file_url` filter — against a library tested for parity with the Ruby
  gem, rather than a bespoke tokenizer we own and debug.
- **The control-flow Liquid (`{% for %}`/`{% unless %}`) lives _only_ in
  `archidep.json.liquid`**, which we are dropping regardless (see [Drop the
  archidep.json round-trip?](#drop-the-archidepjson-round-trip)); prose has
  none. So this decision is independent of that file's fate.

**The one real cost of `Solid`:** strict whole-document parsing is greedy about
delimiters — a future `{{`/`{%` in a code sample (Ansible/Jinja, GitHub Actions
`${{ }}`, Go/Vue templates) becomes a build error unless wrapped in `{% raw %}`.
This is **already true under Jekyll** and is a non-issue today (zero stray
delimiters, zero `{% raw %}` in the content), so it is latent, not active; `{%
raw %}` mitigates it if it ever bites. Not enough to outweigh the above. (A
hand-rolled, delimiter-agnostic preprocessor is the only thing that avoids this
leash entirely — the sole strong argument for that path, and it does not win on
balance.)

**Remaining spike before locking [Custom block tags](#custom-block-tags)**
(~half a day, confirmatory only):

1. `cols` on `Solid`: raw-body block tag → split captured body on
   `<!-- col -->` → MDEx each segment → wrap in the grid divs; assert
   byte-identical output to the current Ruby tag on a real block.
2. One inline path: `{% link _course/…/exercise.md %}` → URL via a custom tag,
   and `{{ x | relative_file_url }}` → asset URL via a custom filter.
3. A fenced code block through MDEx to check raw-HTML-island handling (a
   MDEx-vs-kramdown _fidelity_ check, identical under either implementation
   choice).

### Drop the archidep.json round-trip?

`archidep.json` exists only so the Elixir app could compile a model of the
course without reading raw Jekyll files
(`app/lib/archidep/course/helpers/material_helpers.ex` reads it at compile time,
tracking its SHA to trigger recompiles). Once the **same Elixir core** parses
the Markdown for both the static build and the app ([Shared Markdown rendering
core](#shared-markdown-rendering-core)), the intermediate file may be redundant:
`Course.Material` could compile its model directly from the Markdown sources.

Decide between:

- **Drop it** — `Course.Material` derives sections/cheatsheets/headings from the
  parsed Markdown at compile time; no JSON written for the app's benefit.
- **Keep it as an output artifact** — still emit `archidep.json` if anything
  external (PDF generation, tooling, the archived static site) consumes it, but
  stop treating it as the app's compile-time _input_.

Whichever we pick, the goal is **one source of truth** (the Markdown), not a
Markdown→JSON→module chain. Note `search.json`/`lunr.json` are a separate
concern — see [Search index](#search-index).

### Shared Markdown rendering core

Build `ArchiDep.Course.Renderer` (or similar) as a **plain, dependency-light
module** wrapping MDEx: parse Markdown → AST, run AST passes (tags, anchors,
target-blank, emoji), render HTML. It must be callable from:

- the **static build step** (writes files to `priv/static`), and
- (potentially, later) a **runtime mode** — kept possible but not built now.

Keep it free of Phoenix/web coupling so the static/archival build can run it
standalone. This module is the single seam the rest of the backlog hangs off.

### Custom block tags

Port the six tag files in `course/_plugins/tags/` (`note`, `callout`, `cols`,
`solution`, `mermaid`, `markdown`) as **`Solid` custom tags** (implementation
choice settled — see [Revisit the Solid (Liquid) library
decision](#revisit-the-solid-liquid-library-decision)) that render inner
Markdown with the shared core and emit the **same HTML** the Ruby tags emit
today — **zero content edits**. Each block tag captures its raw body (bodies are
pure Markdown) and feeds it to MDEx, à la `Solid`'s built-in `RawTag`. Counts to
cover: `note` ×317, `callout` ×95, `cols` ×24, `solution` ×23, `mermaid` ×1,
plus the `markdown` wrapper. Mind `callout`'s unique-ID generation for "more"
callouts and `cols`'s `<!-- col -->` splitting. The `solution` tag gains new
gating behaviour — see [Progressive solution
reveal](#progressive-solution-reveal).

Alongside the six block tags, the same `Solid` setup must cover the **inline
Liquid** the content relies on: `{% link path %}` (×94, collection-doc path →
URL), `{% include icons/x.html %}` (×44, SVG inlining), the `relative_file_url`
filter (×22) and `{{ page.title }}` (×3), and `{% highlight %}` (×2, or convert
to fenced code). These are registered as `Solid` custom tags/filters rather than
hand-parsed.

### Progressive solution reveal

New feature to build alongside the migration: **`{% solution %}` blocks are
hidden by default and revealed progressively** as the course advances, driven by
frontmatter flags the same way `progress` already is (see [Metadata
generation](#metadata-generation)). Today every solution is always rendered; we
want to gate them.

Design decisions to settle:

- **Where the flag lives.** Likely a per-document (or per-section) frontmatter
  flag — e.g. `solutions: true` — toggled as the year progresses, mirroring how
  progress docs drive `done`/`due`/`next`/`future`. Decide whether it is a plain
  boolean, a date, or derived from the same progress signal so we flip one
  thing, not two.
- **Hidden must mean omitted, not just CSS-collapsed.** Because both the static
  HTML and the reveal.js slide source are inspectable, a hidden solution should
  be **left out of the rendered output entirely**, so students cannot read it in
  the page source. A `display:none` toggle is not sufficient.
- **Archival/standalone overrides reveal-all.** A frozen archive of a past year
  ([Standalone / archival mode](#standalone--archival-mode)) should render
  **all** solutions — the gating only applies to the live, in-progress build.
  Provide a build option (e.g. `reveal_all_solutions`) the archival build sets.
- **Tests.** Cover hidden-by-default, reveal-on-flag, and archival reveal-all in
  the tag preprocessor unit tests ([Testing as we go](#testing-as-we-go)).

This pairs with [Custom block tags](#custom-block-tags) (the `solution` tag is
where the gate is enforced) and [A richer Course.Material
model](#a-richer-coursematerial-model) (which already carries per-document
progress metadata).

### Reference-link resolution

Reproduce `utils.rb`'s `parse_markdown_link_references` /
`replace_markdown_link_references`: bottom-of-document `[ref]: url` definitions
must be injected into each **extracted tag block** and into **slides** so
reference-style links survive extraction. Small but load-bearing — links inside
notes/callouts/slides break silently without it.

### TOC and heading anchors

Generate heading IDs and the "On this page" navigation from the MDEx AST,
replacing `jekyll-toc` + the `toc_only` filter. Match Jekyll/kramdown's slugging
rules as closely as practical (the [HTML fidelity gate](#html-fidelity-gate)
will surface divergences). The generated, _stable_ IDs are also what [Heading
references that compile-fail](#heading-references-that-compile-fail) will key
off.

### Smaller Jekyll plugins

Replace the remaining plugins:

- **`jemoji`** — `:shortcode:` → emoji; needed in titles _and_ tag output (e.g.
  `:books:`). Port the shortcode→emoji map.
- **`jekyll-target-blank`** — trivial AST pass adding `target="_blank"` to
  external links.
- **`jekyll-seo-tag`** — move into the HEEx `<head>` (and the static layout's
  head for standalone mode).
- **`jekyll-feed`** — drop, or reimplement if the RSS feed is still wanted.

### Slides

Slides are rendered **client-side by reveal.js**; Jekyll only pre-expands Liquid
into `page.raw_markdown` and stuffs it into a `<textarea data-template>` in
`course/_layouts/slides.html`. So the slide path needs the **tag + asset +
reference-link preprocessing** but **not** the Markdown→HTML step. Keep the PDF
download link convention (`/pdf/ArchiDep {num} - {section} - {title} -
Slides.pdf`) and the reveal.js asset wiring.

### Asset URLs

Drop `relative_asset_url.rb`'s dual-manifest dance (webpack `manifest.json` +
Phoenix `cache_manifest.json`). Phoenix's `phx.digest` + verified routes resolve
digested asset paths natively; the renderer should emit asset URLs through that
mechanism. This also removes the build-ordering constraint that currently forces
Jekyll to run after the digest stage (see [What gets simpler, and what is
load-bearing](#what-gets-simpler-and-what-is-load-bearing)). Note:
standalone/archival output must still rewrite asset URLs to work without the app
— see [Standalone / archival mode](#standalone--archival-mode) and, for
versioned builds, [Optional URL prefix](#optional-url-prefix).

### Metadata generation

Port `archidep.rb`'s deterministic logic to Elixir: filename →
`num`/`section`/`section_chapter`/`course_type`/`graded`/`slug`/`url`;
subject↔slides linking; and the `progress` aggregation
(`done`/`due`/`next`/`future`) driven by the progress docs. This is the data
that today populates `archidep.json` and the sidebar; it should feed [A richer
Course.Material model](#a-richer-coursematerial-model) directly.

### A richer Course.Material model

`ArchiDep.Course.Material` **stays a compiled module** — dynamic parts of the
Phoenix app reference it and we _want_ compile-time failures when a reference
goes stale. Today it exposes `course_sections/0`, `course_cheatsheets/0`, and a
few cached lookups (`run_virtual_server_exercise/0`, `sysadmin_cheatsheet/0`).

Improve it so references are **typed and granular**:

- Model sections, documents, cheatsheets (and headings — see below) as
  **structs** rather than raw maps, so callers like `layouts.ex`,
  `server_help_component.ex`, `dashboard_live.ex`, `new_server_dialog_live.ex`
  and the change-username dialog get compile-time guarantees.
- Provide **functions/constants that resolve to a specific document or
  heading**, so a renamed/removed target is a compile error, not a dead link at
  runtime.

### Heading references that compile-fail

Today the app hardcodes brittle URL fragments into Jekyll-generated headings —
**11 in `app/lib/archidep_web/servers/server_help_component.ex`** (e.g.
`#exclamation-create-your-server`,
`#boom-i-forgot-to-open-some-or-all-of-the-ports-in-the-firewall`) plus one in
`app/lib/archidep_web/course/change_username_dialog_live.html.heex`
(`#how-do-i-change-my-username-usermod`). These silently break when a heading is
reworded.

Because we now parse the Markdown in Elixir, make **headings first-class** in
`Course.Material`: expose each referenced heading as a value the app links to
via a function/constant. A missing heading then fails compilation. This is the
single biggest robustness win of the migration and pairs with [TOC and heading
anchors](#toc-and-heading-anchors) (which produces the stable IDs) and [A richer
Course.Material model](#a-richer-coursematerial-model).

### Static build step

Implement an Elixir build task (e.g. a Mix task) that runs the shared core over
all docs/cheatsheets/slides and writes the **same `priv/static` layout** Jekyll
produces today. A build-time flag may gate it **during the migration only** so
both outputs can be generated for the diff; that flag is temporary scaffolding
removed at [Cutover](#cutover), not a permanent production toggle (scorched
earth — see [Goals and constraints](#goals-and-constraints)). This preserves
trivial static serving (`Plug.Static`), PDF generation, and the archival story.
The runtime serving mode stays explicitly out of scope (see [An architectural
fork worth deciding early](#an-architectural-fork-worth-deciding-early)).

### Standalone / archival mode

A **fully static, dashboard-free** build must remain possible — none of the
teacher/student UI, cloud-server details, login, or admin. Preserve the
`archidep_standalone` flag semantics from `course/_config.pages.yml`: in
standalone mode, omit dynamic chrome and emit self-contained HTML/assets
suitable for GitHub Pages. This is both the **previous-years archive** and the
**backup copy** students use when the main server is down. Asset URLs must
resolve without the running app (see [Asset URLs](#asset-urls)).

### Optional URL prefix

Support rendering the whole static site under an **optional path prefix** (e.g.
`/2025-2026/`) so each year's content can be archived as an immutable version
while all versions coexist. Requirements:

- All internal links, asset URLs, and heading anchors must be prefix-aware
  (build-time configuration, default empty prefix = current behaviour).
- Keep it simple: a single configurable base path threaded through the renderer
  and metadata. If it turns out to be disproportionately complex, descope to a
  manual post-build rewrite — but a build-time prefix is the preferred outcome.

### Per-year PDF archive

The per-year PDFs (slides, cheatsheets) generated by `npm run pdf` should be
**kept alongside the archived static site** for that year (e.g. under the year's
prefix, or a parallel archive location). Not strictly part of the rendering
refactor, but a stated goal: decide the storage location/convention so that an
archived `/2025-2026/` site and its PDFs travel together. (Do **not** run `npm
run pdf` casually — it is expensive and human-triggered per project policy.)

### Search index

Keep the existing search pipeline initially: build `search.json` from the
**rendered HTML** using **Floki** (the way `archidep.rb` uses Nokogiri), then
reuse `npm run idx` (`course/src/scripts/idx.ts`) to produce `lunr.json`. This
decouples the search work from the renderer migration and can be revisited
later. Independent of the [Drop the archidep.json
round-trip?](#drop-the-archidepjson-round-trip) decision.

### HTML fidelity gate

The gating QA step. Because we are going scorched earth (no parallel Jekyll
build to diff against later), **first capture a frozen snapshot** of the current
Jekyll HTML output — commit it to a throwaway branch or an ignored directory —
and treat that as the immutable regression baseline. Then render all 59 course
docs + 4 cheatsheets with the new core and **diff page-by-page against the
frozen baseline** until parity is acceptable. Expect small kramdown-vs-comrak
differences (whitespace, slugging, edge cases). Automate the diff and keep a
visual-regression pass. [Cutover](#cutover) — the actual deletion of Jekyll —
does not happen until this passes. This is where the bulk of the [2–4 week
effort](#verdict-and-suggested-path) goes.

### Cutover

Once the gate passes, the removal is **decisive and complete** (scorched earth):
switch the app to the Elixir-rendered output and **delete the entire Jekyll
layer** — the Liquid sidebar/header (`course/_includes/sidebar.html`,
`header.html`) in favour of the single HEEx source of truth, the `_plugins`,
`_layouts`, `_includes`, `_config*.yml`, the `Gemfile`/Bundler setup, and the
Ruby/Jekyll Docker stage and its cross-language hacks. No dual pipeline or
fallback flag is left behind. Keep PDF generation and the search scripts running
against the new output. The frozen baseline snapshot from the [HTML fidelity
gate](#html-fidelity-gate) can be discarded once cutover is confirmed.

---

## What the course actually depends on (measured, not assumed)

The content is ~28,400 lines of Markdown across **59 course files + 4
cheatsheets + 14 progress files**, organized into 8 sections. The
Jekyll-specific surface inside that content is remarkably thin:

| Construct                                                                      | Uses in content        | Nature                         |
| ------------------------------------------------------------------------------ | ---------------------- | ------------------------------ |
| Custom block tags (`note`/`callout`/`cols`/`solution`/`mermaid`)               | 317 / 95 / 24 / 23 / 1 | Own ~50–120-line Ruby files    |
| `{% link path %}` (Jekyll core tag, path → URL)                                | 94                     | Inline cross-doc links         |
| `{% include icons/… %}`                                                        | 44 (all icons)         | SVG inlining                   |
| `{{ … \| relative_file_url }}`                                                 | 22                     | Per-page asset URLs            |
| `{% highlight %}`                                                              | 2                      | Could be plain fenced code     |
| **General Liquid logic** (`if`/`for`/`assign`/`capture`/`case`) **in content** | **0**                  | Only in `archidep.json.liquid` |
| kramdown attribute lists `{:.foo}`                                             | 0                      | —                              |
| Footnotes / definition lists                                                   | 1 / 0                  | negligible                     |

Code fences are all standard languages (`bash` ×756, `yml`, `nginx`,
`Dockerfile`, `php`, …). **The content is essentially CommonMark + GFM plus six
well-defined custom block constructs and a handful of inline Liquid tags/filters
(`{% link %}`, `{% include icons %}`, `relative_file_url`).** There is no
general-purpose control-flow templating (`if`/`for`/`assign`) embedded in the
prose — the only such logic lives in `archidep.json.liquid` (being dropped) and
in layouts/includes, which are the part you would rewrite as HEEx anyway.
Measured against the actual `Solid` source, the block-tag bodies are **pure
Markdown** (no nested Liquid), so they reduce to raw-capture-then-MDEx; see
[Revisit the Solid (Liquid) library
decision](#revisit-the-solid-liquid-library-decision).

---

## The decisive point: half of this is already rendered in Elixir

The strongest argument. The app does **not** treat the course as a black box:

- `app/lib/archidep/course/helpers/material_helpers.ex` reads `archidep.json`
  **at compile time** and `material.ex` exposes `course_sections/0` /
  `course_cheatsheets/0`.
- `app/lib/archidep_web/components/layouts.ex` (≈ lines 213–306) **re-renders
  the entire sidebar in HEEx** from that JSON — iterating the same sections,
  applying the same progress classes, the same icons.

So the sidebar/header already exists **twice**: once in Liquid
(`course/_includes/sidebar.html`, `header.html`) and once in HEEx. Every
navigation/progress change must be made in two languages today. A migration
does not _add_ an Elixir renderer — it lets you **delete the Liquid one** and
keep a single source of truth. This directly attacks the "complex and brittle"
pain.

---

## What gets simpler, and what is load-bearing

**Gets simpler / disappears:**

- The Ruby/Bundler/Jekyll toolchain and a whole Docker stage.
- `relative_asset_url.rb`'s dual-manifest dance (webpack `manifest.json` +
  Phoenix `cache_manifest.json`) — Phoenix's own `phx.digest` + verified routes
  already resolve digested asset paths natively. This is a _built-in_ in Elixir.
- The cross-language hacks: Ruby reading `app/mix.exs` with a regex for the
  version; Jekyll's build forced to run _after_ the digest stage because it
  consumes `cache_manifest.json`. That ordering constraint goes away.

**Unaffected — leave them alone:**

- The WebSocket `me` channel (`user_channel.ex`) for live session +
  cloud-server data — pure runtime, nothing to do with rendering.
- Static serving via `Plug.Static` (whether files come from Jekyll or an Elixir
  build step is irrelevant to the server).
- PDF generation (Puppeteer drives the rendered site) — keep as-is.
- `lunr.json` generation (the `npm run idx` TS script consuming `search.json`)
  — keep initially.

---

## The honest hard parts / risks

1. **Markdown HTML fidelity (the main QA cost).** Jekyll uses **kramdown**; the
   Elixir-native choice is **MDEx** (comrak/Rust NIF: CommonMark + GFM, built-in
   syntax highlighting, AST access). Across 28k lines the output _will_ differ
   in small ways (whitespace, anchor-ID slugging, edge cases). The good news
   from the audit: no attribute lists, ~no footnotes, no definition lists — so
   you are firmly in CommonMark/GFM territory, low-risk. But you will want a
   **diff/visual-regression pass** comparing old vs new HTML page-by-page before
   cutover. Budget real time here. See [HTML fidelity
   gate](#html-fidelity-gate).

2. **The custom block tags.** Do not migrate the _content_ syntax. Implement the
   tags as **`Solid` custom tags** (decided — see [Revisit the Solid (Liquid)
   library decision](#revisit-the-solid-liquid-library-decision)): each block
   tag captures its raw body (block bodies are pure Markdown), renders it with
   MDEx, and emits the same HTML the Ruby tags emit today — **zero content
   edits**. `Solid` also carries the inline companions (`{% link %}`,
   `{% include icons %}`, the `relative_file_url` filter) that a hand-rolled
   scanner would otherwise have to reimplement. See [Custom block
   tags](#custom-block-tags).

3. **Reference-link resolution.** The Ruby `utils.rb` copies bottom-of-doc
   `[ref]: url` definitions into each extracted tag block and into slides so
   reference links survive extraction. You would reproduce that helper in Elixir
   (small, but do not forget it — it is load-bearing for links inside
   notes/callouts and slides). See [Reference-link
   resolution](#reference-link-resolution).

4. **TOC + heading anchors.** `jekyll-toc` + the `toc_only` filter produce the
   "On this page" nav and heading IDs. You would generate IDs and build the TOC
   from the MDEx AST. Modest, well-trodden work. See
   [TOC and heading anchors](#toc-and-heading-anchors).

5. **Smaller Jekyll plugins to replace:** `jemoji` (`:rocket:` shortcodes —
   used in titles _and_ in tag output like `:books:`; needs a shortcode→emoji
   map), `jekyll-target-blank` (trivial AST pass), `jekyll-seo-tag` (HEEx
   `<head>`), `jekyll-feed` (drop or reimplement). See
   [Smaller Jekyll plugins](#smaller-jekyll-plugins).

6. **Slides.** reveal.js renders slide Markdown **client-side** — Jekyll only
   pre-expands Liquid into `raw_markdown`. So slides need the tag/asset
   preprocessing step but **not** the Markdown→HTML step. Easy to get wrong if
   you assume slides are server-rendered. See [Slides](#slides).

7. **Standalone/archival mode** (`_config.pages.yml` → GitHub Pages) must still
   produce fully static, dashboard-free HTML. A static Elixir build step
   preserves this; just keep the `standalone` flag semantics. See
   [Standalone / archival mode](#standalone--archival-mode).

---

## An architectural fork worth deciding early

"Static build step" is the conservative, archival-friendly choice (keeps GitHub
Pages standalone mode and PDF generation trivially). But since rendering would
live _inside the Phoenix app_, the alternative is to **render course pages
dynamically via controllers/LiveView** — which would also eliminate the
`archidep.json`/`search.json` export round-trip and give instant content reload
in dev (no watcher needed). The trade-off: it complicates the standalone
static-archive story and changes the serving model.

**Recommendation:** keep it a **static build step** (matches stated intent and
preserves archival), but structure the renderer as a plain module so a future
runtime mode is possible. This is now a firm decision — see [Goals and
constraints](#goals-and-constraints). Note that "share a core" and "drop
`archidep.json`" are achievable _without_ adopting the runtime serving model;
see [Drop the archidep.json round-trip?](#drop-the-archidepjson-round-trip).

---

## Verdict and suggested path

**Feasible, and well-justified for this specific codebase** — not because
reimplementing Jekyll is cheap in general, but because (a) the content uses a
tiny, clean subset, (b) a parallel HEEx sidebar is already maintained and would
collapse into one source of truth, and (c) Phoenix natively subsumes the
asset-digest plumbing that is currently the most brittle part.

Recommended incremental, low-risk migration:

1. Build a `ArchiDep.Course.Renderer` (MDEx + a tag preprocessor +
   reference-link + TOC helpers) **behind a flag**, writing to the _same_
   `priv/static` layout Jekyll produces.
2. Render all 59+4 docs and **diff the HTML against the current Jekyll output**
   until acceptable parity is reached. This is the gate.
3. Port the metadata generator (`archidep.rb`'s filename→`num`/`section`/
   `progress` logic and the progress-doc aggregation) — straightforward,
   deterministic Elixir.
4. Reuse the existing `npm run idx` for `lunr.json` initially (parse rendered
   HTML with **Floki** the way Ruby uses Nokogiri to build `search.json`).
5. Cut over, delete the Liquid sidebar/header in favor of the HEEx one, drop the
   Ruby stage.

**Effort estimate:** the renderer + tags + metadata is the small part (days).
The dominant cost is **content regression QA across ~28k lines** plus
slides/search/standalone parity — realistically a **2–4 week focused effort**,
front-loaded on the HTML-fidelity diff. The risk is almost entirely "subtle
rendering regressions in actively-used teaching material," which the diff-gate
is designed to contain — not architectural risk.
