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
  - [URL and link emission seam](#url-and-link-emission-seam)
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
  - [Progress: structure vs status](#progress-structure-vs-status)
  - [Static build step](#static-build-step)
  - [Development and production serving](#development-and-production-serving)
  - [Standalone / archival mode](#standalone--archival-mode)
  - [Optional URL prefix](#optional-url-prefix)
  - [Decouple PDF generation from production](#decouple-pdf-generation-from-production)
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
- [x] Decide whether the intermediate `archidep.json` can be dropped. **Decided:
      drop the compile-time round-trip; keep `archidep.json` as a build-output
      artifact for `npm run pdf`** — see [Drop the archidep.json
      round-trip?](#drop-the-archidepjson-round-trip).
- [x] Confirm the static-build-step architecture and defer the runtime mode.
      **Decided: one parameterized static build serves both production and
      archival** (differing only by flags), served by Phoenix in development and
      by a separate static server in production; the runtime rendering mode
      stays deferred — see [Static build step](#static-build-step), [Development
      and production serving](#development-and-production-serving) and [An
      architectural fork worth deciding
      early](#an-architectural-fork-worth-deciding-early).

**Rendering core**

- [ ] Design the URL/link emission seam once, up front: a single
      resolver-strategy the web-decoupled renderer calls, parameterized for
      digesting, an optional path prefix, and an optional absolute base URL —
      see [URL and link emission seam](#url-and-link-emission-seam).
- [ ] Build a shared Markdown-parsing/rendering core (Solid + MDEx + AST
      helpers) reusable by both the static build and the Phoenix app — see
      [Shared Markdown rendering core](#shared-markdown-rendering-core).
- [ ] Port the six custom block tags
      (`note`/`callout`/`cols`/`solution`/`mermaid`/`markdown`) as `Solid`
      custom tags — see [Custom block tags](#custom-block-tags).
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

- [ ] Hide solution blocks by default and reveal them from the progress source
      as the course progresses — see [Progressive solution
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
- [ ] Split progress into compiled _structure_ and a runtime _status source_ (a
      swappable source read by both the baked static build and the
      server-rendered app-shell sidebar), keeping status out of the compiled
      model — see [Progress: structure vs
      status](#progress-structure-vs-status).
- [ ] Make `progress.json` the single progress source (replacing the `_progress`
      collection) and expose current progress at a public, read-only API route
      for the backup build — see [Progress: structure vs
      status](#progress-structure-vs-status).

**Static build, archival and per-year versions**

- [ ] Implement the static build step writing to the same `priv/static` layout
      Jekyll produces — see [Static build step](#static-build-step).
- [ ] Serve the build via Phoenix `Plug.Static` in development and via a
      separate static server (reverse-proxy routed) in production, publishing
      in-process rebuilds atomically to a shared volume — see [Development and
      production serving](#development-and-production-serving).
- [ ] Preserve a fully static, dashboard-free standalone/archival output (GitHub
      Pages backup) — see [Standalone / archival mode](#standalone--archival-mode).
- [ ] Support an optional URL prefix (e.g. `/2025-2026/`) for per-year archived
      versions — see [Optional URL prefix](#optional-url-prefix).
- [ ] Decide where per-year generated PDFs are kept alongside the archived site
      — see [Per-year PDF archive](#per-year-pdf-archive).
- [ ] Decouple PDF generation from the production website: bake absolute
      production URLs into content links at build time and serve the build
      locally — see [Decouple PDF generation from
      production](#decouple-pdf-generation-from-production).

**Search, QA and cutover**

- [ ] Reuse the existing `npm run idx`/`lunr` path initially, building
      `search.json` with Floki — see [Search index](#search-index).
- [ ] Run an HTML fidelity diff / visual-regression gate against current Jekyll
      output — see [HTML fidelity gate](#html-fidelity-gate).
- [ ] Cut over: delete the Liquid sidebar/header, drop the Ruby/Jekyll stage —
      see [Cutover](#cutover).

**Deferred (scheduled after cutover)**

- [ ] Move the progress _status source_ from `progress.json` to a database model
      edited through the admin console, driving an in-process rebuild — see
      [Progress: structure vs status](#progress-structure-vs-status).

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
- **One parameterized static build serves both production and archival, served
  two ways.** Production and archival are the same build under different flags,
  not two renderers. In **development** the Phoenix application serves the build
  output directly (`Plug.Static`) so a developer runs one process; in
  **production** a **separate static server** serves it, with the reverse proxy
  routing course URLs to that server and the dynamic app URLs (`/app`, `/admin`,
  the websocket) to Phoenix — the split the proxy already performs. See
  [Development and production serving](#development-and-production-serving).
- **Course progress splits into compiled _structure_ and a runtime _status
  source_.** `Course.Material` keeps only the structure (sections, documents,
  headings) at compile time; the progress _status_
  (`done`/`due`/`next`/`future`) is read at build/render time from a swappable
  source — a single `progress.json` file now, the database later. It is
  **baked** into
  the static build (jank-free, no client-side injection) while the
  server-rendered app-shell sidebar reads it live. The seam is built during the
  migration; moving the source to the database is deferred. See [Progress:
  structure vs status](#progress-structure-vs-status).
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
- **The intermediate `archidep.json` round-trip is dropped; the file is kept as
  an output artifact.** It was introduced only so the Elixir app had something
  to compile against without reading raw Jekyll files. With one shared Elixir
  Markdown core, `Course.Material` compiles directly from the Markdown sources,
  so the JSON is no longer a compile-time _input_ — but it is still emitted as a
  build _output_ for the `npm run pdf` script, which cannot reach into Elixir.
  See [Drop the archidep.json round-trip?](#drop-the-archidepjson-round-trip).
- **PDF generation must be independent of the production website.** `npm run
pdf` should render against a local build while the PDFs' internal links still
  point to production URLs, achieved by baking a configurable canonical base URL
  into content links at build time (assets stay relative and local). See
  [Decouple PDF generation from
  production](#decouple-pdf-generation-from-production).
- **`Solid` is adopted, not a hand-rolled preprocessor.** The earlier
  `Solid`-is-not-appropriate conclusion was an assumption; a proper analysis
  against the actual content and the `Solid` source reversed it. The custom
  block tags and inline Liquid become `Solid` custom tags/filters. See [Revisit
  the Solid (Liquid) library
  decision](#revisit-the-solid-liquid-library-decision).
- **Clean replacement, not coexistence (scorched earth).** We will not run the
  Jekyll and Elixir pipelines side by side, nor keep a permanent production
  feature-flag fallback. The safety net is the **already-deployed Jekyll build**
  (the previous year's archive at `https://archidep.github.io/website/`, which
  stays up independently) as the visual reference; once the new renderer reaches
  **functional and visual parity** with it — nothing broken, looks good, **not**
  byte-identical — we **delete the entire Jekyll/Ruby toolchain**. Any
  build-time flag is temporary scaffolding for the migration, removed at
  [Cutover](#cutover). See [HTML fidelity gate](#html-fidelity-gate).
- **Everything is unit-tested as we go.** Each new module (renderer, `Solid`
  custom tags, metadata, `Course.Material`) ships with tests in the same change,
  not as a later pass. This is the cross-cutting working agreement for the whole
  plan and follows the [testing conventions](../app/docs/testing.md). See
  [Testing as we go](#testing-as-we-go).
- **Solutions are hidden until explicitly revealed.** Solution blocks must not
  appear until enabled as the course progresses, revealed from the same progress
  source that drives `progress` (not a separate flag) once a chapter's status
  crosses a threshold. This is a new feature built alongside the migration. See
  [Progressive solution reveal](#progressive-solution-reveal) and [Progress:
  structure vs status](#progress-structure-vs-status).

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

- **`Solid` custom tags** — table tests per tag
  (`note`/`callout`/`cols`/`solution`/ `mermaid`/`markdown`): given input
  Markdown, assert the emitted HTML, including edge cases (nested Markdown,
  `cols`' `<!-- col -->` splitting, `callout` unique-ID generation, reference
  links inside blocks).
- **Metadata generation** — deterministic filename→`num`/`section`/`course_type`/
  `progress` mapping and progress aggregation are pure and should be exhaustively
  unit-tested.
- **`Course.Material`** — assert the typed model and that
  document/heading resolvers exist (the compile-fail guarantee itself is the
  ultimate test, but cover lookups too).
- **Solution visibility** — assert hidden-by-default and reveal-on-flag behaviour
  ([Progressive solution reveal](#progressive-solution-reveal)).
- **Fidelity** — the page-by-page functional-and-visual check against the
  already-deployed site is a separate, coarser gate ([HTML fidelity
  gate](#html-fidelity-gate)); unit tests cover behaviour, the gate covers
  "nothing broken, looks good" (not byte parity).

Align all of this with the now-complete testing plan's conventions in
[`app/docs/testing.md`](../app/docs/testing.md) and the app's existing
conventions in [`app/CONTRIBUTING.md`](../app/CONTRIBUTING.md).

### Revisit the Solid (Liquid) library decision

**Decision: adopt [`Solid`](https://hex.pm/packages/solid)** (the pure-Elixir
Liquid implementation, v1.3.2), not a hand-rolled preprocessor. This reverses
the plan's original assumption that `Solid` was not appropriate. The evidence
that flips it, measured against the actual content and the actual `Solid`
source:

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
- **Closest to today's Jekyll behaviour.** `Solid` keeps the same
  whole-document-Liquid-then-Markdown model, whitespace control, and attribute
  conventions, which minimizes gratuitous divergence and eases the [HTML
  fidelity gate](#html-fidelity-gate). We are **not** chasing byte-identical
  output (see that gate), but a hand-rolled preprocessor that is _more_
  permissive about stray delimiters is an avoidable behaviour change.
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
   `<!-- col -->` → MDEx each segment → wrap in the grid divs; assert the output
   is **structurally equivalent** to the current Ruby tag on a real block (same
   grid divs and content — not byte-identical; see [HTML fidelity
   gate](#html-fidelity-gate)).
2. One inline path: `{% link _course/…/exercise.md %}` → URL via a custom tag,
   and `{{ x | relative_file_url }}` → asset URL via a custom filter.
3. A fenced code block through MDEx to check raw-HTML-island handling (a
   MDEx-vs-kramdown _fidelity_ check, identical under either implementation
   choice).

### Drop the archidep.json round-trip?

**Decided: drop the compile-time round-trip, but keep `archidep.json` as a
build-_output_ artifact.** `archidep.json` exists only so the Elixir app could
compile a model of the course without reading raw Jekyll files
(`app/lib/archidep/course/helpers/material_helpers.ex` reads it at compile time,
tracking its SHA to trigger recompiles). Once the **same Elixir core** parses
the Markdown and the metadata generator ([Metadata
generation](#metadata-generation)) computes the derived structure in-process,
`Course.Material` compiles its model **directly from the Markdown sources** —
there is no reason to write JSON and read it back.

The file itself is **not** deleted, because it has a second, independent
consumer the app cannot reach: the `npm run pdf` script
(`course/src/scripts/pdf.ts`), a Node program that reads `archidep.json` to
enumerate the pages to print and to name the output PDFs. So the file's role
flips:

- **As the app's compile-time _input_** — dropped. `Course.Material` derives
  sections/cheatsheets/headings from the parsed Markdown at compile time; no
  JSON is read to build the module.
- **As a build _output_ artifact** — kept. The Elixir static build serializes
  its already-built `Course.Material` model to `archidep.json` so `pdf.ts` keeps
  working unchanged. The shape stays as it is today to avoid churn in `pdf.ts`;
  it can be slimmed later since it is now ours to define.

Consequences to handle when implementing:

- **Replace the recompile trigger.** The `__mix_recompile__?/0` SHA over
  `archidep.json` must be replaced by registering the course docs and
  `_progress` files as `@external_resource`s (or digesting the metadata
  generator's inputs), so a content or progress edit still forces recompilation
  — now tracking the true source instead of a generated proxy.
- **Confirmed consumers.** `pdf.ts` is the only non-app reader (verified across
  `course/src`, the app, and `package.json`); nothing reads the file at app
  runtime.
- **Forward-looking.** Moving progress to a runtime source ([Progress: structure
  vs status](#progress-structure-vs-status)) would make progress dynamic;
  dropping the round-trip removes a serialization layer that transition would
  otherwise have to unwind, so the two do not conflict.

The result is the intended **one source of truth** (the Markdown), not a
Markdown→JSON→module chain — while still emitting the JSON the PDF tooling
needs. Note `search.json`/`lunr.json` are a separate concern — see [Search
index](#search-index).

### URL and link emission seam

Design this **before** the shared core, because four later tasks all thread
through the same point and will otherwise each hardcode a different assumption:
[Asset URLs](#asset-urls) (digested paths), [Optional URL
prefix](#optional-url-prefix) (per-year `/2025-2026/` prefix), [Decouple PDF
generation from production](#decouple-pdf-generation-from-production) (absolute
production URLs on content links, relative on assets) and [Standalone / archival
mode](#standalone--archival-mode) (URLs that resolve with no running app).

There is a real tension to resolve here: the renderer must stay
**web-decoupled** so the static/archival build can run it standalone (see
[Shared Markdown rendering core](#shared-markdown-rendering-core)), yet asset
URLs are meant to go through Phoenix's `phx.digest` + **verified routes**, which
are a compile-time macro bound to the router — i.e. Phoenix coupling. Resolve it
by having the renderer emit **logical paths** and delegate to an **injected
URL-resolver strategy**, with three orthogonal knobs the caller sets:

- **Digesting** — map a logical asset path to its digested filename (the app
  build supplies a resolver backed by `phx.digest`; the standalone build
  supplies one that reads the digest manifest directly, no endpoint needed).
- **Path prefix** — an optional base path (default empty) prepended to internal
  links, asset URLs and heading anchors, for [per-year
  versions](#optional-url-prefix).
- **Absolute base URL** — an optional canonical origin baked onto **content**
  links (not assets) for [PDF
  generation](#decouple-pdf-generation-from-production).

Each consumer is then a configuration of the one seam, not its own rewrite. Unit
tests cover the resolver in isolation (the four knob combinations) so the
consuming tasks inherit correct URLs by construction.

### Shared Markdown rendering core

Build `ArchiDep.Course.Renderer` (or similar) as a **plain, dependency-light
module** wrapping `Solid` + MDEx: run the source through `Solid` (expanding the
custom block and inline tags — see [Custom block tags](#custom-block-tags)),
parse the result to a Markdown AST via MDEx, run AST passes (heading anchors,
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
the same progress source (see [Progress: structure vs
status](#progress-structure-vs-status) and [Metadata
generation](#metadata-generation)). Today every solution is always rendered; we
want to gate them.

Design decisions to settle:

- **Reveal derives from the progress source, not a second flag.** A chapter's
  solutions are revealed once its status crosses a threshold, so we flip one
  thing (progress), not two. The remaining decision is only the **threshold** —
  at `done`, or `done`/`due` — see [Progress: structure vs
  status](#progress-structure-vs-status).
- **Hidden must mean omitted, not just CSS-collapsed.** Because both the static
  HTML and the reveal.js slide source are inspectable, a hidden solution should
  be **left out of the rendered output entirely**, so students cannot read it in
  the page source. A `display:none` toggle is not sufficient.
- **Archival/standalone overrides reveal-all.** A frozen archive of a past year
  ([Standalone / archival mode](#standalone--archival-mode)) should render
  **all** solutions — the gating only applies to the live, in-progress build.
  Provide a build option (e.g. `reveal_all_solutions`) the archival build sets.
- **Tests.** Cover hidden-by-default, reveal-on-flag, and archival reveal-all in
  the `Solid` custom tag unit tests ([Testing as we go](#testing-as-we-go)).

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

### Progress: structure vs status

Course progress has two separable parts that today's Jekyll pipeline conflates
by baking both into `archidep.json` at build time:

- **Structure** — which sections, documents and headings exist, and their order.
  This is inherently build-time and stays in the **compiled** `Course.Material`
  (see [A richer Course.Material model](#a-richer-coursematerial-model)); we
  _want_ compile-time failures when a reference goes stale.
- **Status** — each chapter's `done`/`due`/`next`/`future` state, which changes
  on every teaching session. This is **not** compiled into `Course.Material`; it
  is read at build/render time from a swappable **progress source**.

Two surfaces consume the status, from the one source:

- The **static build** reads it at build time and **bakes** the progress classes
  (`course-section-…`/`course-item-…`) into the static course pages. Changing
  status therefore requires a rebuild — deliberately, the same way [progressive
  solution reveal](#progressive-solution-reveal) is a build-time decision.
- The **server-rendered app-shell sidebar** (`layouts.ex`) reads it at render
  time, so it reflects the source live with no rebuild.

Progress is **never applied client-side**: baking (static pages) and
server-render (app shell) both avoid the flash-of-no-progress a JavaScript
overlay would cause on every page load. This is the key difference from the `me`
websocket channel, which carries genuinely per-user, live data — progress is
global, slowly-changing state that does not need per-request injection.

Solution content, by contrast, lives **only** in the static course build (there
is no live-rendered surface that shows it), which is why [progressive solution
reveal](#progressive-solution-reveal) is build-time in _all_ cases: the two are
consistent, not in tension. Because the status is now a single source,
**solution reveal derives from it** — a chapter's solutions are revealed once
its status crosses a threshold — rather than being a second flag to flip. This
resolves the "one flag or two" open decision in [Progressive solution
reveal](#progressive-solution-reveal); the exact threshold (at `done`, or
`done`/`due`) stays a small policy decision.

**One canonical progress shape.** Today the status lives in a dedicated
`_progress` Jekyll collection (~14 files) that a plugin aggregates. We replace
that collection with a **single `progress.json` file** as the source, kept
indefinitely. One file is trivial to read (versus aggregating a collection), and
— more importantly — the same shape is reused everywhere: it is the file-backed
**source** now, the exact shape the database **exports** later (the database
replaces the _source_, not the _shape_), the **API** response body, and the
**frozen archival snapshot**. Keep `progress.json` a build _input_, distinct
from `archidep.json`, which stays a build _output_ ([Drop the archidep.json
round-trip?](#drop-the-archidepjson-round-trip)).

**Public progress API.** Expose the current progress at a public, read-only
route (e.g. `GET /api/progress`) serving that shape from the source. Its
consumer is the standalone/GitHub-Pages backup build (see [Standalone / archival
mode](#standalone--archival-mode)), whose progress source is **configurable**:
point it at the live API URL during the school year — rebuilt regularly
(manually or automatically) so the backup tracks the course as it advances — or
at a frozen snapshot for the final publish. The **final archive of a year
reveals everything**: all-complete progress plus `reveal_all_solutions`
([Progressive solution reveal](#progressive-solution-reveal)), captured once so
the per-year archive is immutable.

**Built now (the seam):** introduce the progress-source abstraction with the
`progress.json` implementation, add the public API route, wire both build and
app-shell consumers to it, and keep status out of the compiled module. This
keeps `Course.Material` a compiled module of _structure_ while _status_ is a
runtime read — resolving the compile-time-to-runtime question the old
frontmatter design raised (structure stays compiled, status is read from the
source).

**Deferred (scheduled after cutover):** swap the source implementation from
`progress.json` to a **database model** edited through the admin console, so
progress is updated through the UI rather than by editing a file, and a progress
change **enqueues an in-process rebuild** of the static build (a queue, so rapid
edits coalesce and rebuilds run one at a time) that publishes atomically to the
shared volume (see [Development and production
serving](#development-and-production-serving)). Because the seam already exists,
this swap touches one module — not the renderer, `Course.Material`, the API, or
either consumer.

**Open questions to resolve when scheduling the database source:**

- The **granularity** of the stored model: per-session `done`/`due`/`next`
  arrays (as today) versus a per-chapter status, and how the per-chapter state
  is computed.
- The shape of the archival build's progress source: a single knob that is
  either a URL (live) or a frozen/all-complete value, versus separate modes. A
  single snapshot captured once at archival time keeps the per-year archive
  immutable.
- What the rebuild queue looks like (debouncing, failure handling, whether a
  rebuild blocks serving the previous build) and how it interacts with the
  static build task.
- Whether `progress.json` is retained as an export/interchange format once the
  database is the source, or dropped.

### Static build step

Implement an Elixir build task (e.g. a Mix task) that runs the shared core over
all docs/cheatsheets/slides and writes the **same `priv/static` layout** Jekyll
produces today. A build-time flag may gate it **during the migration only** so
both outputs can be generated for the diff; that flag is temporary scaffolding
removed at [Cutover](#cutover), not a permanent production toggle (scorched
earth — see [Goals and constraints](#goals-and-constraints)). This preserves
trivial static serving (`Plug.Static`), PDF generation, and the archival story.
Production and archival are the same build under different flags; how the build
is served differs between development and production — see [Development and
production serving](#development-and-production-serving). The runtime serving
mode stays explicitly out of scope (see [An architectural fork worth deciding
early](#an-architectural-fork-worth-deciding-early)).

### Development and production serving

The single parameterized static build (production and archival differ only by
flags — see [Static build step](#static-build-step) and [Standalone / archival
mode](#standalone--archival-mode)) is served two ways:

- **Development:** the Phoenix application serves the build output directly via
  `Plug.Static`, so a developer runs one process.
- **Production:** a **separate static server** serves the build output; the
  reverse proxy routes course URLs to it and the dynamic app URLs (`/app`,
  `/admin`, the websocket) to Phoenix — the routing split the proxy already
  performs. Production course pages therefore never reach Phoenix at request
  time, which is exactly why progress is **baked** rather than injected (see
  [Progress: structure vs status](#progress-structure-vs-status)).

**Publish path (shared volume).** When the application drives an in-process
rebuild (the deferred database-progress feature, and any content rebuild), it
writes the output to a **volume shared** with the static server. To avoid
serving a half-written build, a rebuild must be **atomic**: render into a
temporary directory on the same volume, then swap it into place (rename, or flip
a `current` symlink) so the static server only ever sees a complete build. The
per-year prefix archives ([Optional URL prefix](#optional-url-prefix)) compose
naturally — each year is an immutable directory under the same volume.

**Asset routing.** Digested asset URLs are emitted at build time (via
`phx.digest` + verified routes — see [Asset URLs](#asset-urls)) as plain strings
in the static HTML; the reverse proxy must route `/assets/…` consistently so
both the static course pages and the dynamic app resolve the same digested
files.

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

### Decouple PDF generation from production

**Goal: `npm run pdf` should run against a local build, not the deployed
production website, while the links inside the PDFs still point to production
URLs.** Today `pdf.ts` is pointed at `https://archidep.ch` because that is the
only way to get production URLs into the exported PDFs — a constraint that ties
an expensive, human-run step to the live site.

The dependency is narrow. Internal links are generated with `relative_url` and
`baseurl` is empty, so anchor hrefs are **root-relative** (`/course/…`). When
Puppeteer prints a page, Chrome resolves those hrefs against the URL it loaded
(`page.goto`), so the serving origin becomes the link target — serve from
localhost and you get localhost links. Nothing in the PDF _content_ needs
production: the pages render client-side (reveal.js, mermaid, the git-memoir
diagrams via the `git-memoir-*` query params) from static assets, and the
dashboard websocket is irrelevant to an anonymous export (and absent in
standalone mode).

**Design principle — split what is currently conflated:** assets load from
wherever Puppeteer fetches (**local, relative**); content cross-links are
**absolute production URLs baked at build time**. Once links are absolute and
assets relative, the PDF is identical regardless of serving origin, so we serve
locally and never touch production.

Do **not** solve this with a `<base href>` element — it also redirects
root-relative _asset_ URLs to the base origin, reintroducing the very dependency
we are removing and breaking local asset loading.

The clean end state (with the Elixir renderer): generalize the [optional URL
prefix](#optional-url-prefix) knob into a **configurable canonical base URL**
threaded through the renderer. The static build emits absolute production URLs
on content links and relative URLs on assets; serve that build locally (a
throwaway `Plug.Static`, or the app in a preview mode) and point Puppeteer at
it. PDF generation then depends on a **build artifact**, not a running site —
reproducible in CI, working offline, and able to regenerate a past year's PDFs
from that year's frozen archive. It composes with the
`archidep.json`-as-output-artifact decision ([Drop the archidep.json
round-trip?](#drop-the-archidepjson-round-trip)): `pdf.ts` reads the emitted
manifest for _what_ to print, and the canonical base URL controls _what the
links say_.

An interim option that works before the renderer lands — serve the current
Jekyll `priv/static` build locally and rewrite root-relative anchor hrefs to the
production origin in a `page.evaluate` just before `page.pdf()` — is available
if decoupling is wanted sooner, but the canonical-base-URL build is the intended
outcome.

**Verify before relying on local serving:** this assumes no course page bakes a
runtime-fetched value into visible content at page load (which would differ
between the production app and a plain static server). None is known to exist —
the pages appear to render entirely client-side from static assets, with the
dashboard websocket carrying only session/cloud-server data irrelevant to an
anonymous export — but confirm it when implementing this task; if one does turn
up, that content would need a static fallback in the export build.

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

The gating QA step — but the bar is **functional and visual parity, not
byte-identical HTML**. What must hold across all 59 course docs + 4 cheatsheets
(and the slides): nothing is broken — links resolve, tags render, code
highlights, TOC/anchors work, navigation and progress classes are correct — and
each page **looks good**. We explicitly **do not** require pixel- or
byte-for-byte reproduction of the Jekyll output; small kramdown-vs-comrak
differences (whitespace, slugging, minor markup) are acceptable as long as the
page reads correctly and looks right.

We do **not** need to commit a frozen HTML snapshot: the previous year's Jekyll
build is **already deployed** at `https://archidep.github.io/website/` and stays
up independently of anything we do to the toolchain, so it (together with the
current running site) is the visual reference to compare against. A page-by-page
HTML diff is still a **useful tool** for surfacing unexpected changes — run one
to catch regressions you would otherwise miss — but it is a spotlight, not a
pass/fail byte gate; the acceptance decision is "nothing broken, looks good."
[Cutover](#cutover) — the actual deletion of Jekyll — does not happen until this
passes.

### Cutover

Once the gate passes, the removal is **decisive and complete** (scorched earth):
switch the app to the Elixir-rendered output and **delete the entire Jekyll
layer** — the Liquid sidebar/header (`course/_includes/sidebar.html`,
`header.html`) in favour of the single HEEx source of truth, the `_plugins`,
`_layouts`, `_includes`, `_config*.yml`, the `Gemfile`/Bundler setup, and the
Ruby/Jekyll Docker stage and its cross-language hacks. No dual pipeline or
fallback flag is left behind. Keep PDF generation and the search scripts running
against the new output. The deployed archive used as the visual reference during
the [HTML fidelity gate](#html-fidelity-gate) stays up as the previous-year
archive regardless — there is nothing to discard after cutover.

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
   you are firmly in CommonMark/GFM territory, low-risk. And the bar is
   **functional + visual parity, not byte-identical output** ([HTML fidelity
   gate](#html-fidelity-gate)), so those small differences are acceptable as
   long as pages read correctly and look good. Still run a **visual-regression /
   spot HTML-diff pass** page-by-page before cutover to catch anything actually
   broken.

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

1. Build a `ArchiDep.Course.Renderer` (`Solid` + MDEx + custom tags +
   reference-link + TOC helpers) **behind a flag**, writing to the _same_
   `priv/static` layout Jekyll produces.
2. Render all 59+4 docs and check them **functionally and visually against the
   current/deployed Jekyll site** — nothing broken, looks good — using an HTML
   diff as a tool, not a byte gate. This is the gate.
3. Port the metadata generator (`archidep.rb`'s filename→`num`/`section`/
   `progress` logic and the progress-doc aggregation) — straightforward,
   deterministic Elixir.
4. Reuse the existing `npm run idx` for `lunr.json` initially (parse rendered
   HTML with **Floki** the way Ruby uses Nokogiri to build `search.json`).
5. Cut over, delete the Liquid sidebar/header in favor of the HEEx one, drop the
   Ruby stage.

**Effort estimate:** the renderer + tags + metadata is the small part (days).
The larger cost is **content regression QA across ~28k lines** plus
slides/search/standalone parity — but because the bar is functional + visual
parity rather than byte-identical output ([HTML fidelity
gate](#html-fidelity-gate)), this is lighter than a strict page-by-page byte
reconciliation would be. The risk is almost entirely "subtle rendering
regressions in actively-used teaching material," which the functional/visual
gate is designed to contain — not architectural risk.
