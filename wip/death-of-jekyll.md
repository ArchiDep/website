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
    - [Typed logical references, not path strings](#typed-logical-references-not-path-strings)
    - [Configuration knobs](#configuration-knobs)
    - [Emission policy per reference kind](#emission-policy-per-reference-kind)
    - [Page-adjacent assets are digested](#page-adjacent-assets-are-digested)
    - [The home page exception](#the-home-page-exception)
    - [Archived years: a banner and one dynamic resolver](#archived-years-a-banner-and-one-dynamic-resolver)
    - [Search assets carry a build id](#search-assets-carry-a-build-id)
    - [Consumers as configurations](#consumers-as-configurations)
    - [Two corrections to the rest of the plan](#two-corrections-to-the-rest-of-the-plan)
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

- [x] Design the URL/link emission seam once, up front. **Decided: the renderer
      emits typed logical references to one injected resolver**, configured by
      `mode` / `base_path` / `version` / `home_at_base?` / `absolute_base_url`
      / `live_site_url` plus the
      asset manifests; page-adjacent assets are digested but stay
      document-relative, the search assets are named with a build id, and the
      home page is emitted at both the base path and the version prefix during
      the year — see [URL and link emission seam](#url-and-link-emission-seam).
- [x] Run the confirmatory `Solid` + MDEx spike before locking the tag design.
      **Done: the decision stands**, with three corrections — prose block bodies
      need nested Liquid parsing rather than raw capture (8 bodies embed
      `{% link %}`), `{% link %}`/`{% include %}` must take raw markup because
      `Solid`'s lexer rejects unquoted paths, and syntax highlighting is the one
      non-drop-in part (rouge → `lumis` classes, touching the theme) — see
      [Spike results](#spike-results).
- [ ] Implement the URL/link emission seam as a standalone module with unit
      tests, ahead of its consumers — see [URL and link emission
      seam](#url-and-link-emission-seam).
- [ ] Build a shared Markdown-parsing/rendering core (Solid + MDEx + AST
      helpers) reusable by both the static build and the Phoenix app — see
      [Shared Markdown rendering core](#shared-markdown-rendering-core).
- [ ] Port the six custom block tags
      (`note`/`callout`/`cols`/`solution`/`mermaid`/`markdown`) as `Solid`
      custom tags — see [Custom block tags](#custom-block-tags).
- [ ] Reproduce reference-link resolution into extracted tag blocks and slides —
      see [Reference-link resolution](#reference-link-resolution).
- [ ] Move syntax highlighting from rouge to `lumis` (MDEx's highlighter):
      replace `theme/src/highlight-{light,dark}.css` with the matching `lumis`
      theme stylesheets and update the `.highlighter-rouge` / `pre.highlight`
      selectors in `theme/src/course.css` — see [Spike results](#spike-results).
- [ ] Fix the two `{% note: %}` tag-name typos in
      `514-certbot-deployment/exercise.md` and `704-render-deployment/exercise.md`,
      which Ruby Liquid tolerates but `Solid` rejects — see [Spike
      results](#spike-results).
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
- [ ] Support an optional URL prefix (e.g. `/2026/`) for per-year archived
      versions — see [Optional URL prefix](#optional-url-prefix).
- [ ] Emit the two "not the current thing" banners from the first build, not at
      year end, driven by a single three-valued `mode`
      (`:live`/`:backup`/`:archive`) — see [Archived years: a banner and one
      dynamic resolver](#archived-years-a-banner-and-one-dynamic-resolver).
- [ ] Build the `/latest/:year/*path` resolver in the app, with a per-year
      archive manifest and a compile-checked mapping (kept as **data**, so a
      client-side resolver can replace it once the app is retired) from archived
      document identities to current ones; legacy unprefixed URLs go through the
      same route, which makes it a [cutover](#cutover) blocker — see [Archived
      years: a banner and one dynamic
      resolver](#archived-years-a-banner-and-one-dynamic-resolver).
- [ ] Decide whether to re-render the 2025–2026 content from its git tag as the
      first `/2025/` archive, seeding the resolver and doubling as fidelity-gate
      input — see [Archived years: a banner and one dynamic
      resolver](#archived-years-a-banner-and-one-dynamic-resolver).
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
  save that year's content under a prefix such as `/2026/` (the **starting
  year** of the academic year), keeping every version of the course. The prefix
  is technically optional but is used in **every** build, archival or not — with
  one exception, the home page, which lives at the site root during the year and
  moves under the prefix in the archive. Generated PDFs for the year should be
  archived alongside. See [URL and link emission
  seam](#url-and-link-emission-seam), [Optional URL prefix](#optional-url-prefix)
  and [Per-year PDF archive](#per-year-pdf-archive).
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
  point to production URLs, achieved by baking a configurable absolute base URL
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

- **Block-tag bodies are Markdown, and a handful also contain a `{% link %}`.**
  Parsing every block-tag body in the corpus turns up **8 bodies containing a
  nested `{% link %}`** (11 tags in all, in `note` and `callout` bodies); no
  body contains any other nested tag, `{% include %}`, or filter. So a prose
  body cannot be captured raw — it is parsed as a **nested parse tree**,
  rendered, and only then handed to MDEx (see [Custom block
  tags](#custom-block-tags) for the corrected shape). `Solid` supports this
  directly via `Solid.Parser.parse_until/3`, which is how its own `if`/`for`
  tags read their bodies, so the cost is one shared helper rather than raw
  capture. The "custom block tags with Markdown-inside are fiddly" objection
  still does not hold, but for a different reason than originally stated.
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
  thin block-tag structs (two shared body helpers — a nested-body one for prose
  bodies and a raw-capture one, à la `RawTag`, for code and diagram bodies) +
  2–3 inline tags + one `relative_file_url` filter — against a library tested
  for parity with the Ruby gem, rather than a bespoke tokenizer we own and
  debug.
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

#### Spike results

The confirmatory spike is **done**; the decision to adopt `Solid` + MDEx
**stands**. Throwaway code and assertions live in `tmp/spike` (`mix test`,
`mix run parse_all.exs`); it renders the real Markdown under
`course/collections` and compares against the HTML Jekyll currently produces
under `app/priv/static`. What it established, step by step:

1. **`cols` on `Solid` works and matches.** A block tag reading its body,
   splitting on `<!-- col -->`, running MDEx per segment and wrapping the
   results in the grid divs reproduces both real blocks tested (the `columns: 3`
   block with an explicit `<!-- col md:col-span-2 -->` and an image, and a
   default two-column block with an implicit first column and a reference link)
   **structurally equivalently** to the Jekyll output. The `key: value`
   attribute form (`{% cols columns: 3 %}`, `{% note type: more %}`) tokenizes
   with `Solid`'s lexer as-is — no custom attribute parsing needed.
2. **The inline path works, with one API constraint.** `{% link %}` resolves
   through an injected resolver, including the multi-line form used in
   `803-docker-isolation` and a trailing `#anchor`. **But `Solid`'s lexer
   rejects unquoted paths containing `/`** (`Unexpected character '/'`), so `{%
link %}` and `{% include %}` must consume their markup **verbatim** up to
   `%}` — as Jekyll's own tags do — rather than via
   `Solid.Lexer.tokenize_tag_end/1`. Separately, **custom filters receive only
   `(name, args)`, with no render context**, so `relative_file_url` cannot reach
   the current page through `Solid`: per-document state must be closed over in a
   filter function built per render. Both fit the [URL and link emission
   seam](#url-and-link-emission-seam) design; neither is a blocker.
3. **Raw HTML islands survive MDEx intact** — with `render: [unsafe: true]`,
   which is required (the default replaces them with
   `<!-- raw HTML omitted -->`). Islands are preserved **byte-for-byte** as
   `MDEx.HtmlBlock`/`MDEx.HtmlInline` nodes, single quotes and self-closing
   slashes included, and a parse → render round-trip is identical to a direct
   render, so AST rewriting (digesting image URLs, heading IDs) is safe.

The spike also **parsed the whole corpus**: 117 of 121 content, layout and
include files parse with `Solid`. The 4 failures are all actionable, and none is
a stray `{{`/`{%` in a code sample — the risk flagged above remains latent:

- `{% seo %}` and `{% feed_meta %}` in `_layouts/slides.html` and
  `_includes/head.html` are plugin tags already covered by [Smaller Jekyll
  plugins](#smaller-jekyll-plugins).
- `{% note: type: tip %}` in `514-certbot-deployment/exercise.md` and
  `{% note: type: more %}` in `704-render-deployment/exercise.md` are **content
  typos** (a stray colon after the tag name). Ruby Liquid tolerates them —
  both render as proper notes today — while `Solid` reads the tag name as
  `note:` and fails. Fix the two sources; no code change is warranted.

Two divergences worth recording for the [HTML fidelity gate](#html-fidelity-gate):

- **Syntax highlighting is the one part that is not a drop-in.** kramdown/rouge
  emits `<div class="language-bash highlighter-rouge"><div class="highlight">
  <pre class="highlight"><code>` with Pygments-style token classes, which is
  exactly what `theme/src/highlight-light.css`, `theme/src/highlight-dark.css`
  and the `.highlighter-rouge` / `pre.highlight` selectors in
  `theme/src/course.css` are written against. MDEx 0.13 highlights through
  [`lumis`](https://hex.pm/packages/lumis) (an optional dependency selected via
  `config :mdex_native, syntax_highlighter: :lumis`), which emits
  `<pre class="lumis">` with `l-*` token classes. `lumis` ships prebuilt
  per-theme stylesheets, including solarized light and dark variants, so the
  migration is to swap the two highlight stylesheets and update the structural
  selectors — a known, bounded task rather than an unknown. Inline code also
  loses its `language-plaintext highlighter-rouge` classes.
- **A lone raw `<img>` line becomes an HTML block, not a paragraph.** kramdown
  wraps it in `<p>`; CommonMark does not. This affects the `<img class='w80'/>`
  lines in `507-dns/subject.md` and similar.

Finally, the spike turned up a **live bug in `course/_plugins/tags/cols.rb`**:
`col_class = m and m[1] ? m[1].strip : ""` binds `col_class` to the `MatchData`
(Ruby's `and` binds looser than `=`), so every column div is emitted as
`class="<!-- col … -->"` and the intended classes — `md:col-span-2` and friends
— have **never** applied. The Elixir port emits the captured class, which is a
deliberate behaviour _fix_; expect those columns to change appearance and check
them during the fidelity gate.

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
by having the renderer emit **logical references** and delegate to an
**injected URL resolver**, configured by the caller.

#### Typed logical references, not path strings

The single most important decision: the renderer never concatenates a prefix
onto a path. It hands the resolver a **typed reference** and receives a string
back. A closed set of reference kinds, each with its own emission policy:

| Reference                     | Meaning                                       |
| ----------------------------- | --------------------------------------------- |
| `{:home}`                     | the course home page                          |
| `{:document, ref}`            | a course document (`{% link %}`, sidebar)     |
| `{:heading, ref, id}`         | a heading inside a document                   |
| `{:cheatsheet, slug}`         | a cheatsheet                                  |
| `{:page_asset, doc, path}`    | an image/PDF co-located with a document       |
| `{:asset, "/assets/…"}`       | a global build asset (bundles, fonts)         |
| `{:site_file, "search.json"}` | a prefixed build output fetched at runtime    |
| `{:root_file, "favicon.ico"}` | a root-anchored file, never prefixed          |
| `{:pdf, doc}`                 | a generated PDF, published alongside the site |
| `{:external, url}`            | passthrough                                   |

Why typed rather than "prepend a base path to a string": three of the four
consumers below need a **different** answer per kind (the home page ignores the
version prefix in one mode, page assets ignore it in _all_ modes, `favicon.ico`
must never be prefixed, only content links take the absolute base URL). A string
prefix cannot express that without every call site knowing the policy — which is
exactly the duplication this task exists to prevent. Typed references also make
a dangling `{% link %}` or a mistyped image path a **build error** instead of a
silent 404, and they let [`Course.Material`](#a-richer-coursematerial-model)
store references rather than URLs, so the compiled model does not bake in a
year.

#### Configuration knobs

```elixir
%UrlContext{
  mode: :live,                       # :live | :backup | :archive
  base_path: "",                     # deployment mount point ("" | "/website")
  version: "2026",                   # year segment, or nil for unversioned
  home_at_base?: true,               # home also lives at base_path
  absolute_base_url: nil,            # baked onto content links, PDF builds only
  live_site_url: "https://archidep.ch",  # off-site target: banner, rel=canonical
  assets: %AssetManifest{},          # logical asset path -> digested path
  page_assets: %PageAssetManifest{}  # source file -> digested output filename
}
```

`content_prefix` is derived as `base_path <> "/" <> version`. The **year is the
starting year** of the academic year, so the 2026–2027 edition is `/2026/`
(display strings such as `archidep_years` stay two-year; only the URL is
shortened).

`base_path` and `version` are kept **separate** rather than pre-concatenated
because the home-page exception needs the deployment mount point on its own:
during the year the home page sits at `base_path`, which is `/` on
`archidep.ch` but `/website/` on the GitHub Pages backup.

Resolution also takes the **current document** (`from:`), needed to express page
assets relative to the page and to leave same-document fragments bare.

#### Emission policy per reference kind

| Kind                       | Version prefix | Digested | Absolute base URL | Form          |
| -------------------------- | -------------- | -------- | ----------------- | ------------- |
| `:home`                    | see below      | no       | yes               | root-relative |
| `:document`, `:cheatsheet` | yes            | no       | yes               | root-relative |
| `:heading`                 | yes¹           | no       | yes¹              | root-relative |
| `:page_asset`              | n/a            | **yes**  | no                | doc-relative  |
| `:asset`                   | yes            | yes      | no                | root-relative |
| `:site_file`               | yes            | id²      | no                | root-relative |
| `:pdf`                     | yes            | no       | no                | root-relative |
| `:root_file`               | **no**         | no       | no                | root-relative |

¹ A fragment in the **current** document stays bare (`#foo`) — no prefix, no
origin — so in-page and in-PDF navigation stays internal. Only cross-document
heading references get the full treatment. (The plan previously said heading
anchors must be prefix-aware; only the cross-document ones are.)

² Not a content digest but a **build id**, because the search index cannot be
content-addressed without a cycle — see [Search assets carry a build
id](#search-assets-carry-a-build-id).

Two rules fall out and are worth stating explicitly, because they are what makes
PDF generation origin-independent (see [Decouple PDF generation from
production](#decouple-pdf-generation-from-production)): **content links may be
absolutized, assets never are**, and **page assets are document-relative, so no
knob touches them at all**.

#### Page-adjacent assets are digested

**Decision: yes — authors keep writing `![CLI](images/cli.jpg)` next to the
page, and the build digests the file.** This is new (today these assets carry no
digest) and it costs less than it looks:

- **Authoring is unchanged.** Content keeps un-digested, co-located, relative
  paths. The rewrite happens on the MDEx AST (`image`/`link` nodes) and, for raw
  HTML nodes and slides, on the HTML fragment.
- **Emitted URLs stay document-relative** — only the filename changes
  (`images/cli-<md5>.jpg`). Consequence: page assets are automatically immune to
  the version prefix, to the GitHub Pages `/website` mount, and to being served
  from a throwaway local server for PDF export. This is a strictly better
  outcome than root-relative digested URLs and removes a whole class of
  knob-interaction bugs.
- **Output layout mirrors the source tree** under the chapter directory, exactly
  as Jekyll does today, so `../images/x.jpg` from `401-cloud-computing/slides.md`
  keeps resolving to the chapter's `images/` directory.
- **Missing files become build errors.** Digesting requires reading the file, so
  `![](images/typo.png)` — today a silent 404 — fails the build.

Traps to handle when implementing:

- **Source-relative in, output-relative out.**
  `_course/401-cloud-computing/slides.md` is one directory _shallower_ in the
  source tree than its output (`/course/401-cloud-computing/slides/`). The
  reference resolves against the document's **source** directory but must be
  emitted relative to its **output** directory. Doing this by hand at each call
  site is how you get the classic off-by-one-`..` bug; the resolver owns it.
- **Raw HTML must be rewritten too.** `401-cloud-computing/slides.md` uses
  `<img src='../images/…'>` directly, and slides are never Markdown-rendered
  (see [Slides](#slides)) — a pure AST pass would miss them and, because the
  un-digested filename no longer exists, they would 404 rather than degrade.
  Cover `img[src]`, `a[href]`, `source[srcset]` and `url()` in inline styles.
- **Add a post-build link check** over the emitted HTML: every relative URL must
  exist in the output tree. It is a few lines with Floki and it closes the loop
  the digest opens.
- **`relative_file_url` is currently a no-op.** In the `pre_render` hook that
  builds `raw_markdown`, `page` is a Liquid drop, not a `Document`, so the
  filter's `respond_to?(:permalink)` guard fails and it returns its argument
  unchanged — the 22 uses emit plain relative paths. Keep the filter name (zero
  content edits) but reimplement it as a real `{:page_asset, …}` lookup.
- **Immutable caching needs a server rule.** A separately-digested tree is not
  in `cache_manifest.json`, so `Plug.Static` will ETag it rather than mark it
  immutable. Because _every_ page asset is digested, the production static
  server can match on extension under the course tree
  (`/20\d\d/course/.*\.(png|jpe?g|webp|gif|svg|pdf)$`) to serve them immutable.

#### The home page exception

**Yes, this works, and it is not a Phoenix routing problem.** Course pages —
including the home page — are **static files**; the Phoenix router never sees
them. `~p` verified routes cover only the dynamic app (`/app`, `/admin`,
`/profile`, `/auth`, `/api`) plus the app's own assets, and none of those are
versioned. So "home at `/` during the year, `/2026/` in the archive" is a
question of _where the build writes a file_, not of compile-time routes.

**Decision: in live mode emit the home page at both `base_path` and
`content_prefix`;** the archival build emits only the prefixed one. Resolving
`{:home}` returns `base_path` when `home_at_base?` is set and `content_prefix`
otherwise, so every link in every page agrees with whichever copy is canonical,
and `<link rel="canonical">` on the non-canonical copy points at it. Emitting
both means `/2026/` never 404s for someone who trims the URL, and it makes a
copy-based archive as correct as a re-rendered one. (The archival build is a
**re-render** anyway — frozen progress plus `reveal_all_solutions` — so the
exception costs one flag, not a special pipeline.)

Three real Phoenix-side consequences remain, none of them blocking:

- **`ArchiDepWeb.static_paths/0`** whitelists first path segments
  (`~w(assets cheatsheets course …)`); it must gain the year segment.
  `Plug.Static`'s `only` is a compile-time plug option, so the year comes from
  `Application.compile_env/2` like `:serve_static` already does. Changing year
  means a recompile — acceptable for a yearly event that changes the content
  anyway.
- **The app shell links into the course** (`layouts.ex` renders the sidebar from
  `Material`). Those URLs must carry the current year's prefix. Keep
  `Course.Material` storing **references** and resolve them in the web layer
  through this same seam with runtime config — that preserves the compile-time
  reference checking the plan wants while keeping URL policy out of the compiled
  module.
- **Legacy URLs.** Moving `/course/…` to `/2026/course/…` invalidates every
  existing bookmark and external link. Handled by the same resolver the archive
  banners use — see [Archived years: a banner and one dynamic
  resolver](#archived-years-a-banner-and-one-dynamic-resolver).

#### Archived years: a banner and one dynamic resolver

**Decision: an archive never redirects away from itself.** A past year keeps
serving its own content at its own URLs; each archived page carries a **banner**
("this is the archived 2025–2026 edition — go to the current version of this
page"), and that link points at a **dynamic route in the app** that resolves the
archived page's identity to the current edition.

The reason it must be dynamic rather than a URL baked at archival time: the
correspondence between an archived page and the current one **changes during the
year** as the course is reworked, so no target known at archival time stays
correct. Routing through the app makes the banner URL stable forever and leaves
only the app's resolution to change — so **archives never need rebuilding** for
their links to stay right. (Re-render a past year only to change the banner
wording or pick up a renderer fix.)

**Route:** `GET /latest/:year/*path`, where `path` is the archived page's path
inside its version prefix. The banner link is then mechanically the page's own
URL with the version prefix swapped for `/latest/<year>/` — no separate identity
encoding to invent, because the path already _is_ the identity (it is the shape
this seam emits). Choose the route name deliberately: it gets baked into every
archive forever.

**Resolution order:**

1. Parse `path` back into `{num, slug, type}`.
2. Match on `{slug, type}` against the current `Course.Material` — pure
   renumbering, the common case, resolves automatically and needs no rule.
3. Otherwise consult an explicit **override table** for that year.
4. Otherwise render a small "this page has no equivalent in the current edition"
   page in the app shell (linking to the current home _and_ back to the
   archive), rather than silently dumping the visitor on the home page.

**The compile-time guarantee — the point of the whole idea:**

- Each archival build emits `course/archives/<year>.json` (the year plus every
  document identity), committed to the repository and read as an
  `@external_resource` so a content change forces recompilation.
- At compile time every archived identity must resolve: by automatic
  `{slug, type}` match, by an override entry, **or by an explicit declaration
  that it is gone**. Anything unresolved is a **compile error**.
- The fallback must be **opt-in per identity, never implicit**. If "no match →
  home" happened automatically, a single rename would silently degrade every
  archived year's links and nobody would notice; the mechanism would quietly
  decay into "everything points at the home page". Requiring an explicit
  `:gone` declaration is exactly what keeps the table honest — and it makes the
  yearly cost the **diff** (a handful of renames and removals), not sixty
  hand-written rules per year.

**Cache semantics: 302, not 301.** The target is year-dependent, so a
permanently-cached redirect would be wrong next year; send `Cache-Control:
no-store` with it.

**One `mode`, three mutually exclusive values — both banners ship from the
start.** A build is never both a backup copy and an archive: the GitHub Pages
deployment holds every year, its current-year directory _is_ the backup copy,
and at year end that directory is **rebuilt** as the final archive. So this is a
lifecycle with one knob, not two independent booleans:

| `mode`     | Where                      | Banner                                                           |
| ---------- | -------------------------- | ---------------------------------------------------------------- |
| `:live`    | archidep.ch, current year  | none                                                             |
| `:backup`  | GitHub Pages, current year | "this is the backup copy" → same path on the live site           |
| `:archive` | **both hosts**, past year  | "this is the archived 2025–2026 edition" → `/latest/:year/*path` |

The `:backup` link needs no resolver and no manifest — the backup tracks the
current build, so the correspondence is the identity and the link is just
`live_site_url` applied to the page's own URL. That same URL is the natural
`<link rel="canonical">` for a backup page: same year, same content, different
host is genuinely duplicate content, and pointing at the live site keeps the
GitHub Pages copy from competing with it in search results. (This is the one
place `rel="canonical"` is the right tool; it is **not** right between an
archive and the current edition.) Only `:archive` needs the
resolver, because only there is the corresponding current page unknowable at
build time. Both banners are [cutover](#cutover) work, not year-end work: the
backup copy exists from day one.

The `:backup` → `:archive` transition is a **rebuild**, never a flag flipped on
an existing output — which is what keeps a single frozen `mode` in every emitted
page and avoids any "both at once" state.

**Hosting: both hosts carry every year.** archidep.ch serves the live current
year _and_ the past years under their prefixes; the GitHub Pages deployment
mirrors all of them plus the current-year backup copy. So a given year has two
`:archive` builds differing only in `base_path` — the seam already handles that,
but the reverse-proxy rules and `static_paths/0` must account for every year
segment on archidep.ch.

The Pages mirror is not redundancy for its own sake: **when the course ends for
good, the dynamic app goes down permanently and GitHub Pages becomes the only
surviving copy.**

That end state has one consequence worth spending nothing on now but designing
_around_: every archive banner points at `/latest/…` on archidep.ch, so those
links die with the app — and with the domain. Two ways across that bridge when
it comes: a **final rebuild of every year** with a terminal configuration
(archives are rebuildable, so this is a rebuild, not a migration), or a
**client-side resolver** shipped with the Pages deployment. Both are much easier
if the resolver's mapping is **data rather than hand-written function clauses**
— keep the archive manifests and the override table as a map the build can also
emit into the static output, and a JavaScript resolver becomes a drop-in.
Compile-time checking works identically either way, so this constraint costs
nothing today.

**Seeding the first archive.** The ideal is to **re-render the 2025–2026 content
from its git tag with the new renderer** at cutover, producing a proper `/2025/`
archive: the mechanism goes live a year earlier, and it doubles as the strongest
possible input for the [HTML fidelity gate](#html-fidelity-gate) — the same
content, renderable side by side against the deployed Jekyll output. It depends
on that year's material staying untouched until the refactoring lands, which may
not survive the run-up to the course.

Two fallbacks if it does not, and neither blocks anything:

- **Post-process the deployed 2025 HTML** — a one-off pass inserting the banner
  and the `noindex` meta into the frozen output. Viable precisely because the
  files are frozen and it is done once; it does not need Jekyll, which is being
  deleted at [cutover](#cutover).
- **Seed the resolver from the old build regardless.** The 2025 deployment
  already contains `archidep.json`, which carries `num`, `course_slug`,
  `course_type` and `url` for every document — exactly the identity the resolver
  needs. So `course/archives/2025.json` can be derived from the old build
  whether or not that year is ever re-rendered, and the compile-checked override
  table starts working immediately.

**Legacy unprefixed URLs** (`/course/104-ssh/`, from before versioning) use the
same machinery, treating "no year" as the last unprefixed edition:
`/course/*` and `/cheatsheets/*` → **301** to `/latest/<legacy-year>/…` (that
mapping genuinely never changes, so it is safe to cache permanently) → **302**
to the current page. The reverse proxy handles the first hop in production and a
catch-all route covers development; because the files no longer exist at the old
paths, `Plug.Static` falls through to the router on its own.

Details worth recording:

- **Fragments survive, best-effort.** A browser applies the original URL's
  fragment to a redirect target that specifies none, so
  `/latest/2025/course/104-ssh/#tunnels` lands on the current SSH subject at
  `#tunnels` when that heading still exists, and harmlessly at the top when it
  does not.
- **Banners are gated on `mode`, never on the presence of a prefix** — the
  `:live` build is also served under a prefix and must show neither.
- When the app is down, an archived banner link dead-ends — acceptable, the
  archive still reads. The **backup** banner is the case that matters here and
  it does not dead-end: it is a plain link to the live site, which is exactly
  what a visitor on the backup copy is looking for.
- The **already-deployed Jekyll archive** predates this and cannot get a banner
  without re-rendering it with the new renderer; treat it as frozen.
- **Archived years are `noindex, follow`** (decided) so search engines send
  visitors to the current edition rather than to a five-year-old page.
  `noindex` keeps the archive out of results; `follow` is what actively points
  crawlers _at_ the current edition, by letting them traverse the banner link.
  `noindex, nofollow` would keep the archive out of results just as well but
  would sever that path. A `rel="canonical"` from the archive to the current
  page is **not** the right tool: canonical means "same content at another URL",
  which stops being true as soon as a chapter is reworked, and it would have to
  be a concrete URL baked at build time — reintroducing exactly the staleness
  the resolver exists to avoid.
- Crawl budget is not a concern at this size, so `follow` costs nothing.

#### Search assets carry a build id

**A content digest is impossible, but the files still need versioned names.**

The impossibility is a genuine cycle: `search.json` is built _from_ the rendered
HTML (the way `archidep.rb` does it with Nokogiri today — see [Search
index](#search-index)), and its URL has to appear _in_ that HTML's `<head>`
(today `data-base-path`, which the client joins with `/lunr.json`). Digesting
the content would make the HTML depend on a file derived from the HTML.

The version prefix does **not** rescue this. Only the final frozen archive is
immutable; the two builds that matter day to day are rewritten in place under
the _current_ year's prefix:

- the **production build**, rebuilt on every progress change — which changes
  revealed solutions and therefore the indexed text ([Progressive solution
  reveal](#progressive-solution-reveal)); and
- the **GitHub Pages backup**, rebuilt regularly through the year so it tracks
  the course ([Progress: structure vs status](#progress-structure-vs-status)),
  where we do not control cache headers at all.

**Decision: name them `search-<build_id>.json` / `lunr-<build_id>.json`,** where
`build_id` hashes the build _inputs_ (content, progress, config, renderer
version). Inputs are known before rendering, so there is no cycle.

What that buys, honestly, differs by host:

- **On our own static server** — consistency plus genuinely long-lived
  immutable caching.
- **On GitHub Pages** — consistency only. Pages serves everything with a fixed
  ~10-minute `max-age` and no way to configure it, so a versioned name does not
  extend the cache lifetime there. It does guarantee that a freshly-built page
  never fetches the previous build's index, which is the failure that actually
  hurts: results pointing at anchors that moved, and new pages missing from
  search.

Implementation notes:

- `idx.ts` keeps writing a fixed `lunr.json`; the build copies it to the
  versioned name. No change to the Node scripts.
- Emit **full URLs** into `<head>` (`data-search-data-url`,
  `data-search-index-url`) through `{:site_file, …}`, and drop `search.ts`'s
  `${basePath}/lunr.json` string-joining — that call site is precisely the kind
  this seam exists to remove. Keep `data-base-path` only if something else still
  needs it.
- `archidep.json` gets no build id (read from disk by `pdf.ts`, never fetched by
  a browser), and neither does `version.json` (nothing fetches it).

**Alternative considered:** a small, stable pointer file naming content-digested
index files — true content-addressing, so an unchanged index survives a rebuild
in cache, at the cost of one extra request before the first search. Rejected
because revealed solutions and ordinary content edits change the index on most
rebuilds anyway, so the indirection buys little.

#### Consumers as configurations

| Build                 | `mode`     | `base_path`  | `version` | `home_at_base?` | `absolute_base_url`     |
| --------------------- | ---------- | ------------ | --------- | --------------- | ----------------------- |
| Development / live    | `:live`    | `""`         | `"2026"`  | `true`          | `nil`                   |
| GitHub Pages backup   | `:backup`  | `"/website"` | `"2026"`  | `true`          | `nil`                   |
| Archive, archidep.ch  | `:archive` | `""`         | `"2025"`  | `false`         | `nil`                   |
| Archive, GitHub Pages | `:archive` | `"/website"` | `"2025"`  | `false`         | `nil`                   |
| PDF export            | `:live`    | `""`         | `"2026"`  | `true`          | `"https://archidep.ch"` |

`absolute_base_url` is `nil` everywhere except the PDF build — in particular the
**backup copy must keep its content links local**. Absolutizing them to
archidep.ch would point every link at the very site whose downtime the backup
exists to survive. The backup reaches the live site only through
`live_site_url`, and only in two places: the banner link and `<link
rel="canonical">`.

The PDF row is the proof the split works: content links come out absolute, page
assets stay document-relative and global assets stay root-relative, so the build
can be served from `localhost` and still print production links — no
`<base href>`, no running site.

#### Two corrections to the rest of the plan

- **Global assets are copied per version, not shared.** For an archive to stay
  correct forever, each year's build must carry its own `/<year>/assets/…`
  (copied from the app's digested output at build time). A shared root
  `/assets/` would break frozen archives as soon as a later year's asset build
  removes the digested files they reference — and it would leave `/assets`
  ambiguous between Phoenix and the static server at the reverse proxy.
- **The build-ordering constraint does not fully go away.** [Asset
  URLs](#asset-urls) claims `phx.digest` removes the ordering constraint; what
  it removes is the _cross-language_ dual-manifest dance. Rendering still has to
  run after the asset bundles are digested, because the HTML embeds their names.
  The order is: bundle → digest → collect/digest page assets → render → build
  the search index.

Each consumer is then a configuration of the one seam, not its own rewrite. Unit
tests cover the resolver in isolation (every reference kind × the knob
combinations above, plus the source-relative/output-relative page-asset cases)
so the consuming tasks inherit correct URLs by construction.

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

Three MDEx options are **required**, not stylistic, and the spike verified each
against real content (see [Spike results](#spike-results)):

- `render: [unsafe: true]` — otherwise every raw HTML island in the content is
  replaced by `<!-- raw HTML omitted -->`. The input is our own Markdown, so
  this is safe.
- `parse: [smart: true]` — kramdown applies smart punctuation today (`it’s`,
  not `it's`); without this every apostrophe and quote in the corpus changes.
- `extension: [header_id_prefix: ""]` — generates the heading IDs the TOC,
  content anchors and the app all depend on (see [TOC and heading
  anchors](#toc-and-heading-anchors)).

A parse → render round-trip is byte-identical to a direct render, so inserting
AST passes between them is safe.

### Custom block tags

Port the six tag files in `course/_plugins/tags/` (`note`, `callout`, `cols`,
`solution`, `mermaid`, `markdown`) as **`Solid` custom tags** (implementation
choice settled — see [Revisit the Solid (Liquid) library
decision](#revisit-the-solid-liquid-library-decision)) that render inner
Markdown with the shared core and emit the **same HTML** the Ruby tags emit
today — **zero content edits** beyond the two `{% note: %}` typos the spike
found (see [Spike results](#spike-results)). Bodies come in two flavours,
confirmed by the spike:

- **Prose bodies** (`note`, `callout`, `cols`, `solution`, `markdown`) are
  parsed as a **nested Liquid parse tree** via `Solid.Parser.parse_until/3`,
  rendered, and then fed to MDEx — 8 `note`/`callout` bodies embed a
  `{% link %}` that Jekyll resolves today, so raw capture would leak the tag
  into the page as literal text.
- **Code and diagram bodies** (`mermaid`, `highlight`) are captured **raw**, à
  la `Solid`'s built-in `RawTag`, so a `{{` inside a sample cannot become a
  parse error.

Counts to cover: `note` ×317, `callout` ×95, `cols` ×24, `solution` ×23,
`mermaid` ×1, plus the `markdown` wrapper (which the content does not currently
use). Mind `callout`'s unique-ID generation for "more" callouts and `cols`'s
`<!-- col -->` splitting. The `solution` tag gains new gating behaviour — see
[Progressive solution reveal](#progressive-solution-reveal).

Alongside the six block tags, the same `Solid` setup must cover the **inline
Liquid** the content relies on: `{% link path %}` (×94, collection-doc path →
URL), `{% include icons/x.html %}` (×44, SVG inlining), the `relative_file_url`
filter (×22) and `{{ page.title }}` (×3), and `{% highlight %}` (×2, or convert
to fenced code — both uses pass `mark_lines="4"`, which maps onto `lumis`'
`highlight_lines` option). These are registered as `Solid` custom tags/filters
rather than hand-parsed — with the two API constraints the spike surfaced: `{% link %}` and
`{% include %}` consume their markup verbatim up to `%}` (their unquoted paths
contain `/`, which `Solid`'s lexer rejects), and `relative_file_url` is built as
a per-document closure because `Solid` custom filters get no render context.

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

The spike found a simpler mechanism than the Ruby one: rather than rewriting
`][ref]` to `](url)` with a regex, **append the collected definitions to the
extracted body** before handing it to MDEx and let CommonMark resolve them
natively. Extraction of the definitions is still ours — they are the trailing
run of `[ref]: url` lines at the end of the document — but the substitution is
not. This is what `tmp/spike` does, and it reproduces the reference link in the
`101-command-line` `cols` block exactly.

### TOC and heading anchors

Generate heading IDs and the "On this page" navigation from the MDEx AST,
replacing `jekyll-toc` + the `toc_only` filter. The generated, _stable_ IDs are
also what [Heading references that
compile-fail](#heading-references-that-compile-fail) will key off.

**Slugging needs no custom work.** The spike compared MDEx's
`header_id_prefix: ""` slugs against the IDs Jekyll actually emitted, for every
heading of every non-slide course document: **685 of 685 match**, including the
awkward cases — emoji shortcodes (`### :exclamation: Create your server` →
`exclamation-create-your-server`), dotted words (`Gandi.net` → `gandinet`) and
inline code in headings. So this item is only the TOC, not a slugger.

### Smaller Jekyll plugins

Replace the remaining plugins:

- **`jemoji`** — `:shortcode:` → emoji; needed in titles _and_ tag output (e.g.
  `:books:`). Port the shortcode→emoji map. **Ordering constraint:** heading IDs
  are slugged from the _shortcode_ text, not the emoji — `### :exclamation: Create
  your server` is `#exclamation-create-your-server`, and the app links to it —
  so emoji substitution must run **after** heading IDs are generated.
- **`jekyll-target-blank`** — trivial AST pass adding `target="_blank"` to
  external links. It must run on the **logical** references, before the [URL and
  link emission seam](#url-and-link-emission-seam) absolutizes content links:
  once a PDF build has rewritten internal links to `https://archidep.ch/…` they
  are indistinguishable from external ones by inspection.
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
mechanism — behind the [URL and link emission
seam](#url-and-link-emission-seam), as an injected manifest rather than a
compile-time `~p` macro, so the renderer stays web-decoupled. This removes the
_cross-language_ manifest dance that currently forces Jekyll to run after the
digest stage (see [What gets simpler, and what is
load-bearing](#what-gets-simpler-and-what-is-load-bearing)) — but **not** the
underlying ordering: rendering still runs after the asset bundles are digested,
because the HTML embeds their digested names.

Two things the seam adds on top of today's behaviour: **page-adjacent assets
(the images next to each course page) are digested too**, which they are not
today, and each versioned build carries its own copy of the global assets under
its prefix. Standalone/archival output must still resolve asset URLs without the
app — see [Standalone / archival mode](#standalone--archival-mode) and, for
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

All 10 distinct fragments the app hardcodes today are reproduced verbatim by the
MDEx slugger, so this task is a pure robustness change: **no anchor has to move,
and no redirect is needed** to keep existing links working.

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
`/2026/`, the starting year of the academic year) so each year's content can be
archived as an immutable version while all versions coexist. The prefix is
optional in the code but used in every real build; the mechanism is the
`version` knob of the [URL and link emission
seam](#url-and-link-emission-seam), which settles the details:

- Internal links, global asset URLs, generated PDFs and cross-document heading
  references are prefixed; page-adjacent assets stay document-relative and
  fragments within the current document stay bare; `favicon.ico`/`robots.txt`
  stay root-anchored.
- The **home page is the one exception**: emitted at both the base path and the
  prefix during the year, at the prefix only in the archive.
- Each year's build carries **its own copy of the global assets** under the
  prefix, so a frozen archive cannot be broken by a later year's asset build.
- Archived years are **not** redirected away from; they carry a banner pointing
  at a dynamic resolver in the app, which also handles the unprefixed legacy
  paths (`/course/…`, `/cheatsheets/…`) so existing bookmarks and external links
  keep working — see [Archived years: a banner and one dynamic
  resolver](#archived-years-a-banner-and-one-dynamic-resolver).

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

The clean end state (with the Elixir renderer): a **configurable absolute base
URL** alongside the [optional URL prefix](#optional-url-prefix), both knobs of
the [URL and link emission seam](#url-and-link-emission-seam) — kept separate
because the base URL applies only to content links, while the prefix also
applies to global assets. It is set for the **PDF build only**; every other
build leaves it `nil`. The static build emits absolute production URLs
on content links and relative URLs on assets; serve that build locally (a
throwaway `Plug.Static`, or the app in a preview mode) and point Puppeteer at
it. PDF generation then depends on a **build artifact**, not a running site —
reproducible in CI, working offline, and able to regenerate a past year's PDFs
from that year's frozen archive. It composes with the
`archidep.json`-as-output-artifact decision ([Drop the archidep.json
round-trip?](#drop-the-archidepjson-round-trip)): `pdf.ts` reads the emitted
manifest for _what_ to print, and the absolute base URL controls _what the links
say_.

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

Both files are emitted under the version prefix and named with a **build id**
(`lunr-<build_id>.json`) rather than a content digest — `search.json` is derived
from the rendered HTML whose `<head>` has to name it, so content-addressing
would be circular, while the frequently-rebuilt production and backup copies
still need a versioned name to stay consistent with the pages they index. See
[Search assets carry a build id](#search-assets-carry-a-build-id). The URLs the
index stores (`id`, `url`) come from the [URL and link emission
seam](#url-and-link-emission-seam) like every other content link, so they are
prefix- and origin-correct by construction.

### HTML fidelity gate

The gating QA step — but the bar is **functional and visual parity, not
byte-identical HTML**. What must hold across all 59 course docs + 4 cheatsheets
(and the slides): nothing is broken — links resolve, tags render, code
highlights, TOC/anchors work, navigation and progress classes are correct — and
each page **looks good**. Three divergences are **known and expected**, so look
for them deliberately rather than treating them as regressions: code blocks
restyled from rouge to `lumis`, lone raw `<img>` lines no longer wrapped in
`<p>`, and the `cols` column classes finally applying (see [Spike
results](#spike-results)). We explicitly **do not** require pixel- or
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
