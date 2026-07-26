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
    - [Spike results](#spike-results)
  - [Drop the archidep.json round-trip?](#drop-the-archidepjson-round-trip)
  - [URL and link emission seam](#url-and-link-emission-seam)
    - [Typed logical references, not path strings](#typed-logical-references-not-path-strings)
    - [Configuration knobs](#configuration-knobs)
    - [Emission policy per reference kind](#emission-policy-per-reference-kind)
    - [Page-adjacent assets are digested](#page-adjacent-assets-are-digested)
    - [Generated PDFs may live anywhere](#generated-pdfs-may-live-anywhere)
    - [The home page exception](#the-home-page-exception)
    - [Archived years: a banner and one dynamic resolver](#archived-years-a-banner-and-one-dynamic-resolver)
    - [Search assets carry a build id](#search-assets-carry-a-build-id)
    - [Consumers as configurations](#consumers-as-configurations)
    - [Two corrections to the rest of the plan](#two-corrections-to-the-rest-of-the-plan)
  - [Shared Markdown rendering core](#shared-markdown-rendering-core)
  - [Custom block tags](#custom-block-tags)
  - [Syntax highlighting](#syntax-highlighting)
  - [Progressive solution reveal](#progressive-solution-reveal)
  - [Reference-link resolution](#reference-link-resolution)
  - [TOC and heading anchors](#toc-and-heading-anchors)
  - [Smaller Jekyll plugins](#smaller-jekyll-plugins)
    - [One emoji vocabulary](#one-emoji-vocabulary)
  - [Slides](#slides)
  - [Asset URLs](#asset-urls)
  - [Chapter document invariants](#chapter-document-invariants)
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
- [x] Implement the URL/link emission seam as a standalone module with unit
      tests, ahead of its consumers. **Done: `ArchiDep.CourseSite.Urls`** and
      its identity/manifest modules, in a new top-level `ArchiDep.CourseSite.*`
      namespace outside the bounded contexts (documented in
      [`app/lib/archidep/course_site/CONTRIBUTING.md`](../app/lib/archidep/course_site/CONTRIBUTING.md)),
      with six spec corrections recorded below — see [URL and link emission
      seam](#url-and-link-emission-seam).
- [x] Build a shared Markdown-parsing/rendering core (Solid + MDEx + AST
      helpers) reusable by both the static build and the Phoenix app. **Done:
      `ArchiDep.CourseSite.Renderer`** and its submodules, including the inline
      Liquid (`{% link %}`, `{% include %}`, `relative_file_url`), with five
      spec corrections recorded below — see [Shared Markdown rendering
      core](#shared-markdown-rendering-core).
- [x] Port the six custom block tags
      (`note`/`callout`/`cols`/`solution`/`mermaid`/`markdown`) as `Solid`
      custom tags. **Done**, with three Ruby bugs fixed rather than reproduced
      and four spec corrections recorded below; the tag output of every subject,
      exercise and cheatsheet was diffed against a Jekyll build — see [Custom
      block tags](#custom-block-tags).
- [x] Reproduce reference-link resolution into extracted tag blocks and slides.
      **Done: `Source` collects the definitions, `Markdown` appends them to
      every fragment it parses, and `render_slides/1` substitutes them into the
      deck**, the two paths differing because a deck never reaches a Markdown
      renderer — see [Reference-link resolution](#reference-link-resolution).
- [x] Handle the two `{% highlight %}` blocks of `101-command-line/subject.md`,
      the last unported tag and the one thing that stopped that document from
      rendering at all. **Done: both are fenced code blocks carrying MDEx's
      `highlight_lines="4"` decorator**, so there is no `highlight` tag to port
      and the document renders. The mark itself waits on the `lumis` swap below,
      and the decorator costs those two blocks their Jekyll rendering — see
      [Custom block tags](#custom-block-tags).
- [x] Move syntax highlighting from rouge to `lumis`, replacing
      `theme/src/highlight-{light,dark}.css` with `lumis` theme stylesheets and
      the `.highlighter-rouge` / `pre.highlight` selectors of
      `theme/src/course.css` with the markup `lumis` emits. **Done:
      `ArchiDep.CourseSite.Renderer.Highlighter` calls `lumis` directly** rather
      than enabling MDEx's own highlighter, whose adapter breaks a token
      spanning more than one line, and the two stylesheets are generated by `mix
theme.highlight_css`; the fence decorator is documented in the course writing
      guidelines with three corrections recorded below — see [Syntax
      highlighting](#syntax-highlighting).
- [x] Fix the two `{% note: %}` tag-name typos in
      `514-certbot-deployment/exercise.md` and
      `704-render-deployment/exercise.md`, which Ruby Liquid tolerates but
      `Solid` rejects. **Done**; both documents render, and both notes keep
      rendering under Jekyll — see [Spike results](#spike-results).
- [x] Generate heading IDs and the "On this page" TOC from the AST — see [TOC
      and heading anchors](#toc-and-heading-anchors). **Done:
      `ArchiDep.CourseSite.Renderer.Toc` reads the navigation off the finished
      page rather than off the AST**, because that is where the identifiers are
      assigned, and `HeadingIdentifiers` keeps a heading's emoji shortcode out
      of its identifier — a deliberate behaviour change that moves 359 anchors,
      recorded below.
- [x] Replace `jemoji` with one emoji vocabulary the course material and the
      application share. **Done: one closed registry (`ArchiDep.Emoji`) and one
      emitter, drawing self-hosted Twemoji SVGs**, swept over the finished page
      by `EmojiImages`, with eight corrections recorded below — see [One emoji
      vocabulary](#one-emoji-vocabulary).
- [ ] Replace the three remaining Jekyll plugins (`target-blank`, `seo-tag`,
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

- [ ] Enforce the two chapter document invariants — a chapter has a subject or
      an exercise but never both, and an exercise never has slides — as a hard
      build failure listing every offending chapter — see [Chapter document
      invariants](#chapter-document-invariants).
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
- [ ] Derive the dashboard-free chrome policy from `mode` instead of the host,
      port it as one explicit list of dynamic chrome, and apply its two
      non-`:live` rules: the sidebar's app-navigation icon submenu is dropped
      entirely (not reduced to its home entry) in `:backup` and `:archive`, and
      the home page's progress cards are hidden unconditionally in `:archive` —
      see [Standalone / archival mode](#standalone--archival-mode).
- [ ] Support an optional URL prefix (e.g. `/2026/`) for per-year archived
      versions — see [Optional URL prefix](#optional-url-prefix).
- [ ] Emit the two "not the current thing" banners from the first build, not at
      year end, driven by a single three-valued `mode`
      (`:live`/`:backup`/`:archive`) — see [Archived years: a banner and one
      dynamic resolver](#archived-years-a-banner-and-one-dynamic-resolver).
- [ ] Build the `/latest?to=…` resolver in the app, with a per-year archive
      manifest and a compile-checked mapping (kept as **data**, so a client-side
      resolver can replace it once the app is retired) from archived document
      identities to current ones — see [Archived years: a banner and one dynamic
      resolver](#archived-years-a-banner-and-one-dynamic-resolver).
- [ ] Redirect the unprefixed legacy paths **into the 2025 archive**, not to the
      resolver — `301` from `/course/*` and `/cheatsheets/*` to the same path
      under `/2025/`, in the reverse proxy, with a catch-all route covering
      development. A [cutover](#cutover) blocker, since moving the content under
      a prefix breaks every existing bookmark the moment it happens — see
      [Archived years: a banner and one dynamic
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
- [ ] Move PDF generation and publication into CI, replacing the human-run export
      and the manual upload, and feed the resulting locations back through
      `PdfManifest` — see [Decouple PDF generation from
      production](#decouple-pdf-generation-from-production) and [Per-year PDF
      archive](#per-year-pdf-archive).

**Search, QA and cutover**

- [ ] Reuse the existing `npm run idx`/`lunr` path initially, building
      `search.json` with Floki — see [Search index](#search-index).
- [ ] Draw the search dialog's own icons from the emoji registry. `search.ts`
      writes the five type icons and the two of its result and empty-state
      templates as characters, which is the last place the [emoji
      vocabulary](#one-emoji-vocabulary) is not enforced; the client needs a
      generated name→URL map, since only the build knows the digested names —
      see [Search index](#search-index).
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
- **A chapter holds a subject or an exercise, never both — and an exercise never
  has slides.** These are **rules the content must obey**, not observations
  about today's corpus (which does obey them: 19 subjects, 26 exercises and 5
  slides-only chapters out of 50, and none of the 14 chapters with slides is an
  exercise). They are load-bearing rather than cosmetic — a chapter's subject
  and its exercise would otherwise be two different documents at one URL — so
  the build **fails hard** on a chapter that breaks either, instead of picking a
  winner. See [Chapter document invariants](#chapter-document-invariants).
- **The intermediate `archidep.json` round-trip is dropped; the file is kept as
  an output artifact.** It was introduced only so the Elixir app had something
  to compile against without reading raw Jekyll files. With one shared Elixir
  Markdown core, `Course.Material` compiles directly from the Markdown sources,
  so the JSON is no longer a compile-time _input_ — but it is still emitted as a
  build _output_ for the `npm run pdf` script, which cannot reach into Elixir.
  See [Drop the archidep.json round-trip?](#drop-the-archidepjson-round-trip).
- **PDF generation must be independent of the production website, and it must
  become part of CI.** `npm run pdf` should render against a local build while
  the PDFs' internal links still point to production URLs, achieved by baking a
  configurable absolute base URL into content links at build time (assets stay
  relative and local). Independence from a running site is what unlocks the
  rest: today the export is an expensive step a human runs and then uploads by
  hand, and the end state is an **automated CI job** that generates the PDFs
  from a build artifact and publishes them, so no edition's slides are ever
  missing because nobody got round to exporting them. See [Decouple PDF
  generation from production](#decouple-pdf-generation-from-production) and
  [Per-year PDF archive](#per-year-pdf-archive).
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
  `note:` and fails. Fix the two sources; no code change is warranted. **Both
  are fixed**, and both documents render.

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
  loses its `language-plaintext highlighter-rouge` classes. `lumis` also subsumes
  what `{% highlight %}`'s `mark_lines` did: a fence decorator asks for the line
  and `l-highlighted` replaces the `.highlight .hll` rule of the two highlight
  stylesheets (see [Custom block tags](#custom-block-tags)). **This is done**,
  though not by enabling MDEx's highlighter — see [Syntax
  highlighting](#syntax-highlighting).
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
prefix](#optional-url-prefix) (per-year `/2025/` prefix), [Decouple PDF
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

| Reference                       | Meaning                                               |
| ------------------------------- | ----------------------------------------------------- |
| `{:home}`                       | the course home page                                  |
| `{:document, ref}`              | a course document (`{% link %}`, sidebar)             |
| `{:heading, ref, id}`           | a heading inside a document                           |
| `{:cheatsheet, slug}`           | a cheatsheet                                          |
| `{:page_asset, doc, path}`      | an image/PDF co-located with a document               |
| `{:asset, "/assets/…"}`         | a global build asset (bundles, fonts)                 |
| `{:site_file, "archidep.json"}` | a prefixed build output                               |
| `{:build_file, "lunr.json"}`    | ditto, named after the build that produced it         |
| `{:root_file, "favicon.ico"}`   | a file anchored at the mount point                    |
| `{:pdf, page}`                  | a generated PDF, published anywhere                   |
| `{:live_site, page}`            | this page on the live site (backup banner, canonical) |
| `{:current_edition, page}`      | whatever superseded this page (archive banner)        |
| `{:external, url}`              | passthrough                                           |

Three kinds were added to this table during implementation. `{:site_file, …}`
was **split** in two, because the search index must carry the build id while
`archidep.json` and `version.json` must not, and nothing in the original design
distinguished them. `{:live_site, page}` and `{:current_edition, page}` were
added because `mode` and `live_site_url` were otherwise **dead struct fields**:
the design described both banners and `rel=canonical` as URL construction but
gave the layout no way to ask for them, which is exactly the
string-concatenation this seam exists to remove.

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
  build_id: "abc123",                # hashes the build inputs; names the search assets
  absolute_base_url: nil,            # baked onto content links, PDF builds only
  live_site_url: "https://archidep.ch",  # off-site target: banner, rel=canonical
  assets: %AssetManifest{},          # logical asset path -> digested path
  page_assets: %PageAssetManifest{}, # output path -> digested filename
  pdfs: %PdfManifest{}               # where the PDFs are published, and their names
}
```

Three corrections to this struct, applied during implementation:

- **`build_id` was missing** although the `search-<build_id>.json` decision
  below depends on it.
- **`home_at_base?` is gone**, because it is `mode != :archive` in every row of
  the [consumers table](#consumers-as-configurations) — it was a fourth
  representable state with no meaning. It is now derived
  (`UrlContext.home_at_base?/1`), so a build cannot claim to be both.
- **`pdfs` was missing**, and it is not just a name map — see [Generated
  PDFs](#generated-pdfs-may-live-anywhere).

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

| Kind                             | Version prefix | Digested | Absolute base URL | Form                  |
| -------------------------------- | -------------- | -------- | ----------------- | --------------------- |
| `:home`                          | see below      | no       | yes               | root-relative         |
| `:document`, `:cheatsheet`       | yes            | no       | yes               | root-relative         |
| `:heading`                       | yes¹           | no       | yes¹              | root-relative         |
| `:page_asset`                    | n/a            | **yes**  | no                | doc-relative          |
| `:asset`                         | yes            | yes      | no                | root-relative         |
| `:site_file`                     | yes            | no       | no                | root-relative         |
| `:build_file`                    | yes            | id²      | no                | root-relative         |
| `:pdf`                           | yes³           | no       | no                | root-relative³        |
| `:root_file`                     | **no**         | no       | no                | mount-point-relative⁴ |
| `:live_site`, `:current_edition` | n/a            | no       | n/a               | absolute              |

¹ A fragment in the **current** document stays bare (`#foo`) — no prefix, no
origin — so in-page and in-PDF navigation stays internal. Only cross-document
heading references get the full treatment. (The plan previously said heading
anchors must be prefix-aware; only the cross-document ones are.)

² Not a content digest but a **build id**, because the search index cannot be
content-addressed without a cycle — see [Search assets carry a build
id](#search-assets-carry-a-build-id).

³ Unless the PDFs are published externally, in which case the URL is absolute
and neither prefix applies — see [Generated
PDFs](#generated-pdfs-may-live-anywhere).

⁴ "Never prefixed" means never **version**-prefixed: `favicon.ico` is emitted
under `base_path`, so it still resolves on the GitHub Pages mount (which is what
`relative_url` does today).

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
  (`images/cli-<md5>.jpg`), and the author's own path shape is preserved
  verbatim, `../` and `./` included. Consequence: page assets are automatically
  immune to the version prefix, to the GitHub Pages `/website` mount, and to
  being served from a throwaway local server for PDF export. This is a strictly
  better outcome than root-relative digested URLs and removes a whole class of
  knob-interaction bugs, and it is pinned as a property test (the same reference
  under two unrelated build configurations must emit the same string).
- **Output layout mirrors the source tree** under the chapter directory, exactly
  as Jekyll does today, so `../images/x.jpg` from
  `401-cloud-computing/slides.md` keeps resolving to the chapter's `images/`
  directory.
- **Missing files become build errors.** Digesting requires reading the file, so
  `![](images/typo.png)` — today a silent 404 — fails the build.

Traps to handle when implementing:

- **Output-relative in _and_ out** (corrected during implementation; this
  paragraph previously said source-relative in, and following it would have
  _caused_ the off-by-one-`..` bug it warns about).
  `_course/401-cloud-computing/slides.md` writes
  `<img src='../images/client-server.jpg'>` and is one directory _shallower_ in
  the source tree than its output (`/course/401-cloud-computing/slides/`).
  Source-relative, that reference is `_course/images/…`, which does not exist;
  output-relative it is `/course/401-cloud-computing/images/…`, which does — and
  Jekyll agrees, since `relative_asset_url.rb` resolves against
  `page.permalink`. So the reference resolves against the document's **output**
  directory, which also makes resolution layout-blind: the two slides layouts
  differ only in the source tree, so one code path covers both. The manifest is
  therefore keyed by **output path** (not source file) and the resolver never
  reads the source tree at all — the build step, which copies and digests the
  files, owns output→source.
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

#### Generated PDFs may live anywhere

**Decision: the seam supports both site-hosted and arbitrary external PDF
hosting, because external hosting is where this is going.** Today's PDFs are
generated by `npm run pdf` and **uploaded to the server by hand** (they are not
part of the build at all — `pdf/` is in `_config.yml`'s `exclude`). The intended
end state is a **CI job** that generates them and publishes them somewhere the
server does not have to store them: a GitHub release, an S3 bucket.

That end state is what the `{:url, …}` override below is really for. Both levels
of the manifest are then written by the publish step rather than by a human, so
the seam's job is to stay indifferent to which it gets.

`PdfManifest` therefore carries two levels:

- **A base** — `:site` (under the build's own prefix, at `/<year>/pdf/…`) or
  `{:external, base_url}`. This is the deployment fact, so moving the PDFs from
  the server to a bucket is a one-line configuration change and **no resolver
  change at all**.
- **A per-entry `{:url, …}` override** — because some hosts rename what they are
  given (GitHub release assets turn spaces into periods), which makes the URL
  impossible to derive from the local filename. A publish step that knows the
  real asset URLs records them and they pass through verbatim, with no second
  manifest and no per-host special case.

Two consequences worth stating:

- **PDF URLs are absolute iff published externally**, independently of
  `absolute_base_url`, which governs _content_ links only.
- **`:pdf` is the one kind whose absence is not a build error.** A chapter's
  slides may simply not have been exported yet, so an unresolved PDF is a signal
  for the layout to **omit the download link** — today's layout renders it
  unconditionally, which is how a link to a missing PDF becomes possible in the
  first place. A missing _page asset_, by contrast, always fails the build.
  Automating the export in CI does not remove this: the PDFs are generated
  _from_ a build, so a build can never require its own, and new content is
  always rendered at least once before its PDF exists.

If the PDFs do stay site-hosted, note that the version prefix moves their
location: the publish target becomes `/<year>/pdf/`. See [Per-year PDF
archive](#per-year-pdf-archive).

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

**Route:** `GET /latest?to=<path>`, where `to` is the archived page's **own URL
path, version prefix included** — so the banner link is mechanically
`"/latest?to=" <> the page's own path`, with no separate identity encoding to
invent, because the path already _is_ the identity (it is the shape this seam
emits). Choose this shape deliberately: it gets baked into every archive
forever.

**Why a query parameter rather than `/latest/:year/*path`.** The deciding
criterion is the end state below — the day the app goes down, this URL must keep
working from a static host with the least ceremony. `?to=` needs one file at
`/latest/index.html` plus the mapping JSON, on any host, answering 200.
Path-based would need `/latest/2025/course/104-ssh/` to fall through to a
custom-404 page that reads `location.pathname` — a GitHub-Pages-specific trick
that answers HTTP 404 and breaks on any host without that fallback. The query
form is also strictly simpler today: the year prefix is already part of the
archived page's path, so a separate `:year` segment splits one identity into two
parameters for no gain, and the banner rule stops having to assume the prefix is
exactly the year.

Two rules this shape brings with it, both to be stated rather than left
implicit:

- **`to` is an open-redirect shape and is treated as one.** Its value is only
  ever _matched against the archive manifests_; it is never used as a redirect
  target. Anything unknown, off-site or unparseable goes to the "no equivalent"
  page below — never to a redirect.
- **Encoding is normalised on parse.** Slashes are legal unencoded in a query
  string, so `?to=/2025/course/104-ssh/` and its percent-encoded form must
  resolve identically.

**Resolution order:**

1. Parse `to` back into a year plus `{num, slug, type}`.
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

| `mode`     | Where                      | Banner                                                    |
| ---------- | -------------------------- | --------------------------------------------------------- |
| `:live`    | archidep.ch, current year  | none                                                      |
| `:backup`  | GitHub Pages, current year | "this is the backup copy" → same path on the live site    |
| `:archive` | **both hosts**, past year  | "this is the archived 2025–2026 edition" → `/latest?to=…` |

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
_around_: every archive banner points at `/latest?to=…` on archidep.ch, so those
links die with the app — and with the domain. Two ways across that bridge when
it comes: a **final rebuild of every year** with a terminal configuration
(archives are rebuildable, so this is a rebuild, not a migration), or a
**client-side resolver** shipped with the Pages deployment. Both are much easier
if the resolver's mapping is **data rather than hand-written function clauses**
— keep the archive manifests and the override table as a map the build can also
emit into the static output, and a JavaScript resolver becomes a drop-in: a
static `/latest/index.html` reading `to` from `location.search` against that
map, which is exactly why the route takes a query parameter. Compile-time
checking works identically either way, so this constraint costs nothing today.

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

**Legacy unprefixed URLs** (`/course/104-ssh/`, from before versioning) are
**the 2025–2026 archive's own URLs**, and therefore fall under the same rule as
every other archive URL: they land on the archive, which offers the banner. They
do **not** go through the resolver.

`/course/*` → **301** `/2025/course/*` and `/cheatsheets/*` → **301**
`/2025/cheatsheets/*`, then the archived page's banner does the rest. The
mapping is a pure path rewrite with nothing year-dependent in it, so the 301 is
honest and permanently cacheable. The reverse proxy handles it in production and
a catch-all route covers development; because the files no longer exist at the
old paths, `Plug.Static` falls through to the router on its own.

The course has only existed since 2025, so **there is exactly one unprefixed
edition and there will never be another** — this is a fixed pair of rules, not a
mechanism that grows a case per year.

**Rejected: `/course/*` → the current page** (via the resolver, as an earlier
draft had it). The reading behind it is not unreasonable — `/course/104-ssh/`
never meant "the 2025 edition", it meant "the SSH chapter of whatever is
current", since for its whole life it tracked the live course. It loses anyway:

- It would make the largest population of inbound links to the archive — every
  external link and bookmark predating versioning — the one case that _does_
  redirect away from itself, turning the rule into a decoration.
- It can dead-end where the archive would not: an identity declared `:gone`
  yields the "no equivalent" page, for a document that exists and reads fine at
  `/2025/course/104-ssh/`.
- It welds every legacy URL to the dynamic app, which this design otherwise
  works to avoid. A path rewrite keeps serving from the reverse proxy — or any
  static host — after the app is gone.
- Its one real advantage, preserving accumulated search standing, is largely
  illusory: the chain ends in a `302` + `no-store`, which is precisely how one
  tells a crawler _not_ to transfer standing to the target. Direct 301s to
  concrete current URLs would preserve it, but that is the baked-at-build-time
  staleness the resolver exists to eliminate, plus proxy-rule churn every year.

The cost of the decision, stated plainly: someone arriving from an old bookmark
lands on old content and must click once. That is the same bargain already made
for everyone who arrives at `/2025/…` directly, and they did ask for that URL.

Details worth recording:

- **Fragments survive, best-effort, through every hop.** A browser applies the
  original URL's fragment to a redirect target that specifies none, so
  `/course/104-ssh/#tunnels` lands at `#tunnels` on the archived page, and
  `/latest?to=/2025/course/104-ssh/#tunnels` lands at `#tunnels` on the current
  SSH subject — in both cases when that heading still exists, and harmlessly at
  the top when it does not. This is not an argument for either route shape: the
  fragment sits outside the query string in both, so it behaves identically. It
  must **not** be folded into the `to` value in an attempt to "carry" it.
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
  `data-search-index-url`) through `{:build_file, …}` (the build-id-carrying
  counterpart of `{:site_file, …}`), and drop `search.ts`'s
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

| Build                 | `mode`     | `base_path`  | `version` | `absolute_base_url`     |
| --------------------- | ---------- | ------------ | --------- | ----------------------- |
| Development / live    | `:live`    | `""`         | `"2026"`  | `nil`                   |
| GitHub Pages backup   | `:backup`  | `"/website"` | `"2026"`  | `nil`                   |
| Archive, archidep.ch  | `:archive` | `""`         | `"2025"`  | `nil`                   |
| Archive, GitHub Pages | `:archive` | `"/website"` | `"2025"`  | `nil`                   |
| PDF export            | `:live`    | `""`         | `"2026"`  | `"https://archidep.ch"` |

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

Each consumer is then a configuration of the one seam, not its own rewrite.

**Implemented** as `ArchiDep.CourseSite.Urls` (plus `DocumentRef`, `PageRef`,
`UrlContext`, the three manifests, `UrlPath` and `UrlError`) in a new top-level
`ArchiDep.CourseSite.*` namespace, deliberately outside the bounded contexts:
the subsystem owns no state, answers no requests, and must run standalone, so a
stray `Repo` call in it should read as obviously wrong.
`ArchiDep.Course.Material` stays in the Course context for now — the [richer
model task](#a-richer-coursematerial-model) decides whether it moves — and will
store these references rather than URLs. See
[`app/lib/archidep/course_site/CONTRIBUTING.md`](../app/lib/archidep/course_site/CONTRIBUTING.md).

Tests cover the resolver in isolation: one block per reference kind, plus a
block asserting **every kind at once under each of the five configurations
above** (the only place knob interactions are pinned, with expectations written
by hand from the emission table). The claims the consuming tasks actually rely
on are pinned as property tests over generated contexts — page assets unaffected
by how the build is published, global assets never absolutized, same-page
headings always bare, and the identity round-trips — so those tasks inherit
correct URLs by construction.

Two smaller findings from the implementation, neither affecting the design:

- **A chapter URL cannot tell a subject from an exercise**, because a chapter
  never has both. So the inverse direction (`parse_output_path/1`, needed by the
  `/latest?to=…` resolver) returns a deliberately weaker **identity** rather
  than fabricating a type: `{:chapter, num, slug}`, `{:chapter_slides, num,
slug}` or `{:cheatsheet, slug}`. That identity is what the archive resolver
  matches on anyway. This was recorded here as an observation about the corpus;
  it is in fact a rule the content must obey and the build must enforce — see
  [Chapter document invariants](#chapter-document-invariants).
- **No cosmetic `./` divergence after all.** An earlier note here predicted that
  `./images/x.png` would normalize to `images/x.png`; because only the last path
  segment is replaced, the author's prefix survives untouched, so there is
  nothing for the fidelity gate to look at.

### Shared Markdown rendering core

**Implemented** as `ArchiDep.CourseSite.Renderer` (plus `Source`,
`RenderContext`, `RenderOptions`, `RenderError`, `Markdown`, `Excerpt`, `Page`,
`Slides`, the `AstPass`/`HtmlPass` behaviours and the `Liquid.*` submodules), in
the same namespace as the [URL seam](#url-and-link-emission-seam) rather than in
the `Course` context — the renderer belongs with the seam it drives, outside the
bounded contexts, and it is documented in
[`app/lib/archidep/course_site/CONTRIBUTING.md`](../app/lib/archidep/course_site/CONTRIBUTING.md).
It ships with the inline Liquid (`{% link %}`, `{% include %}`,
`relative_file_url`), so the URL seam has its first consumer; the six block tags
are the [next task](#custom-block-tags), which plugs into the tag table.

Five corrections to this section, found while implementing it:

- **Two pass seams, not one.** This section listed heading anchors, target-blank
  and emoji as AST passes. Only rewrites that must see a _Markdown document_ can
  be: a block tag converts its own body during the Liquid stage, so by the time
  the page's document exists that body is one opaque HTML node — and **184 links
  in 28 files** live inside block-tag bodies, plus every emoji shortcode a tag
  emits in its own wrapper. `target-blank` and `jemoji` are therefore
  `HtmlPass`es over the finished page. This also makes the ordering constraint
  in [Smaller Jekyll plugins](#smaller-jekyll-plugins) structural rather than a
  rule to remember: heading identifiers are produced while rendering, emoji run
  after.
- **The excerpt is split on the parsed document.** `<!-- more -->` survives
  parsing as a top-level HTML block, so the page is cut there rather than in the
  source text — which means a separator inside a code block cannot mis-split the
  page, and both halves keep their reference links, since those are resolved at
  parse time. This replaces Jekyll's `remove_first` string match. A document
  that declares no separator is cut after its first block, which is Jekyll's
  default. Declaring a separator and never writing it is a **render error**: the
  page is cut after its first block so the rest of its problems are still
  reported, but the omission fails the build rather than silently becoming
  all-excerpt as it is today. The **five documents that do this** — the subjects
  of chapters 411, 505 and 601, and the decks of chapters 801 and 804 — have to
  be fixed by writing the separator or dropping the front matter key. (Only the
  three subjects are checked: a deck is never split, so a separator in a deck's
  front matter is inert either way.)
- **Slides substitute their link references rather than appending them.** This
  plan's [Reference-link resolution](#reference-link-resolution) section says
  the definitions are appended to slides; they cannot be. reveal.js splits a
  deck into sections and converts each one on its own, so definitions at the
  bottom would only ever serve the last slide. Jekyll does the substitution for
  slides in its generator (`archidep.rb`, not the `pre_render` hook), and the
  port does the same. Appending remains right for a page, where one Markdown
  document is parsed as a whole.
- **The spike's attribute parser rejects most real tags**, and the whole-corpus
  parse did not catch it because the stub tags never tokenized their markup.
  `Solid`'s lexer emits a `:comma` token, which `{% callout type: more, id:
what-is-npm %}` (×24 and counting) hits, and a quoted value arrives as a
  four-element token that the spike's value clause does not match. Both are
  fixed and pinned with a table test over the real markup the content writes.
- **A render error is an exception, and locations are shifted once.** `Solid`
  requires a custom filter's failure to be `{:error, exception, fallback}` and
  calls `Exception.message/1` on it, so the error type implements `Exception`.
  Note also that `Solid.render/3` only reports `{:error, …}` for _its own_
  undefined-variable and undefined-filter errors, so a renderer error arrives on
  the `{:ok, …}` branch: the core treats a non-empty error list as a failure
  whichever branch it came on. Errors carry the line of the file, not of the
  body, which the front matter's length is added back to at the end.

One thing also worth recording for the [fidelity gate](#html-fidelity-gate):
MDEx adds an empty anchor element inside every heading (the identifiers
themselves are unchanged). Code blocks are coloured by `lumis`, which the
renderer calls itself — see [Syntax highlighting](#syntax-highlighting).

The original design, for the record:

Build the renderer as a **plain, dependency-light module** wrapping `Solid` +
MDEx: run the source through `Solid` (expanding the custom block and inline tags
— see [Custom block tags](#custom-block-tags)), parse the result to a Markdown
AST via MDEx, run AST passes (heading anchors, target-blank, emoji), render
HTML. It must be callable from:

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

**Implemented** as `ArchiDep.CourseSite.Renderer.Liquid.{Note,Callout,Cols,Solution,Markdown,Mermaid}Tag`,
plus `TagIcon` (an icon is the same `icons/…` partial the content includes by
hand) and `Partial` (extracted from `IncludeTag`, so a partial the build was
never given is reported in one wording wherever it was asked for). They are
documented in
[`app/lib/archidep/course_site/CONTRIBUTING.md`](../app/lib/archidep/course_site/CONTRIBUTING.md).

**Zero content edits were needed by the six tags**, as this section predicted:
the classes, identifiers and structure every tag of every subject, exercise and
cheatsheet emits were diffed against the Jekyll build in
`tmp/app-priv-static-2026-07-25` and match, save the three fixes below. The two
`{% note: %}` typos and the two `{% highlight %}` blocks of
`101-command-line/subject.md` have since been fixed in the content, so the only
documents that still do not render are the three subjects that declare an
excerpt separator they never write (chapters 411, 505 and 601 — see [Shared
Markdown rendering core](#shared-markdown-rendering-core)).

Five corrections to this section, found while implementing it:

- **Three Ruby bugs are fixed rather than reproduced.** (1) A `cols` column has
  never carried the classes its marker asks for: `col_class = m and m[1] ? … :
…` parses as `(col_class = m) and …` in Ruby, so `col_class` is the
  `MatchData` and every column is emitted as `class="&lt;!-- col md:col-span-2
--&gt;"`. The classes are already in the stylesheet — Tailwind scans the
  Markdown they are written in — so fixing the tag is enough to make the layouts
  the content asks for appear, and **five documents change visually** as a
  result. (2) A folded callout of a cheatsheet was named `-`, because the prefix
  came from `page["num"]` / `page["course_slug"]`, which Jekyll's generator only
  sets for a chapter; the port derives it from the `PageRef`. (3) The
  congratulation and the emoji next to it were drawn with `Array#sample` on
  every render, which a build that is a function of its inputs cannot do; both
  are derived from the callout's identifier instead.
- **A callout's identifier is checked per document, not per site.** Ruby kept a
  site-wide set and raised on a duplicate, but the identifier it emits is
  already prefixed with the page, so the collision that actually breaks a page
  is a repeat within one document — which is what `Registers` now tracks. A name
  that is missing, malformed or taken is replaced by a positional one and
  reported, so the fold still works while the build fails over the name.
- **A value a tag cannot use falls back and is reported; only markup it cannot
  read is a parse error.** Ruby raises for every one of them, which would make a
  mistyped note kind suppress the page and every other problem on it. This
  section's own doctrine — [reporting rather than
  raising](#shared-markdown-rendering-core) — says otherwise, so an aside of an
  unknown kind is shown as a plain note and a row of thirteen columns as a row
  of two. `Solid` also makes parse-time validation the worse choice
  mechanically: it resumes parsing just after the tag name, so one bad attribute
  becomes an error about the attributes _and_ one about the unmatched `{%
endnote %}`.
- **The `solution` gate is not part of this.** `RenderOptions` already carries
  `reveal_all_solutions`, but nothing reads it yet: the gate needs the progress
  source, and its threshold is still undecided — see [Progressive solution
  reveal](#progressive-solution-reveal). The tag renders every solution, as
  today.
- **`{% highlight %}` is not ported at all: a fence says what it said.** MDEx
  reads `lumis` options from a code fence's info string (its [code block
  decorators](https://mdex.hexdocs.pm/code_block_decorators.html)), so a fence
  opened with `bash highlight_lines="4"` is `{% highlight bash mark_lines="4"
%}` with nothing left for a tag to do, and the two blocks of
  `101-command-line/subject.md` — the whole of the tag's use in the corpus — are
  now fences. `lumis` puts `l-highlighted` on the line the decorator names,
  which is the `.hll` span rouge emits today. One consequence, accepted:
  **kramdown does not tolerate the decorator** — its fenced-block pattern
  accepts a bare language token and nothing else, so under Jekyll these two
  blocks now render as literal text. That is a transitional regression on two
  blocks of one chapter, and it is the reason this is a content edit rather than
  a ported tag: no fence syntax satisfies both renderers, and neither does a
  plain fence, which loses the mark outright.

The original design, for the record:

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
rather than hand-parsed — with the two API constraints the spike surfaced: `{%
link %}` and `{% include %}` consume their markup verbatim up to `%}` (their
unquoted paths contain `/`, which `Solid`'s lexer rejects), and
`relative_file_url` is built as a per-document closure because `Solid` custom
filters get no render context.

### Syntax highlighting

Move highlighting from rouge to [`lumis`](https://hexdocs.pm/lumis): the two
`theme/src/highlight-{light,dark}.css` stylesheets and the `.highlighter-rouge`
/ `pre.highlight` selectors of `theme/src/course.css` are written against the
markup kramdown and rouge emit, and `lumis` emits `<pre class="lumis">` with
`l-*` classes instead — see [Spike results](#spike-results).

**Done** (`ArchiDep.CourseSite.Renderer.Highlighter`), with three corrections:

- **`lumis` is called directly, not through MDEx.** MDEx highlights a block and
  then splits the HTML it gets back on newlines to wrap each line in a `<div
class="l-line">`, which severs every token spanning more than one line: **257 of
  the corpus's 926 fenced blocks** come out with unbalanced markup that way (333
  unclosed spans, 21 of them a coloured scope whose continuation lines lose
  their colour), a blank line in a shell transcript being the common case.
  Calling `Lumis.highlight!/2` per code block produces the markup lumis
  documents, and is also what marks a line with the `l-highlighted` class the
  theme stylesheets define rather than the `highlighted` class MDEx's adapter
  asks for and no stylesheet styles. So there is **no `config :mdex_native,
syntax_highlighter: :lumis`** and no 15 MB NIF variant to build; `lumis` stays a
  direct dependency, which it already was. The fence decorator syntax the
  content and the writing guidelines use is unchanged — the renderer parses the
  info string itself, supports `highlight_lines` and reports any other decorator
  as an error on the document, which is how a typo in a fence is caught.
- **The two stylesheets are generated, by `mix theme.highlight_css`.** They are
  one rule per token class of a colour scheme, a few hundred of them, so they
  are built with `Lumis.Theme.build_css!/2` from the themes the task names —
  `solarized_autumn_light` and `solarized_autumn_dark`, the pair whose keyword,
  string, comment and function colours are the ones the current light stylesheet
  already uses. The dark one is the same CSS inside the `prefers-color-scheme:
dark` query the theme uses everywhere else. The light scheme is therefore
  unchanged and the dark one moves from its high-contrast palette to Solarized
  Dark.
- **A marked line is coloured by the scheme, not by the old yellow bar.**
  `.highlight .hll` painted `#eeee00`; `l-highlighted` is the theme's own
  highlight colour, which is subtler in both schemes. The structural part of
  what `.hll` did is in `course.css`: a marked line is an `inline-block` of
  `min-width: 100%` so that its background follows the code when the block
  scrolls sideways, which the old negative-margin trick was for.

One transitional consequence, until [cutover](#cutover): the pages Jekyll builds
lose their highlighting, since the stylesheets they load no longer style rouge's
classes. Code blocks fall back to the `prose` styling of a `pre`, which is
legible in both colour schemes.

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

**Done, with the two paths differing** (`ArchiDep.CourseSite.Renderer.Source`):
appending works for a **page**, which is one Markdown document, so a tag body
and both halves of the page all resolve their references. It does **not** work
for **slides**, which never reach a Markdown renderer and are split into
sections by reveal.js in the browser — appended definitions would serve only the
last slide. Slides therefore keep the Ruby substitution (`][ref]` → `](url)`),
which is what Jekyll's generator already does to `item.content` before the
`pre_render` hook builds `raw_markdown`.

### TOC and heading anchors

**Implemented** as `ArchiDep.CourseSite.Renderer.Toc` (plus `Toc.Entry`, and the
`toc` a rendered `Page` now carries) and
`ArchiDep.CourseSite.Renderer.HeadingIdentifiers`, both documented in
[`app/lib/archidep/course_site/CONTRIBUTING.md`](../app/lib/archidep/course_site/CONTRIBUTING.md).
The IDs are what [Heading references that
compile-fail](#heading-references-that-compile-fail) keys off.

**Slugging needed no custom work**, as this section predicted. The spike
compared MDEx's `header_id_prefix: ""` slugs against the IDs Jekyll actually
emitted, for every heading of every non-slide course document: **685 of 685
match**, including the awkward cases — dotted words (`Gandi.net` → `gandinet`)
and inline code in headings. The one thing that _is_ slugged differently is
deliberate, and is the first correction below.

Four corrections to this section, three of them found while implementing it and
the first a decision taken with it:

- **An emoji shortcode is no longer part of a heading's identifier.** `###
:exclamation: Create your server` was identified by
  `exclamation-create-your-server`, which was never intentional: the shortcode
  says the reader has something to do here and belongs in the anchor no more
  than the words' capitalisation does. It cannot simply be dropped before
  rendering, because the heading still has to show it — and MDEx offers no way
  to hand a heading an identifier (`attrs.id` set on the node is ignored, and so
  is the `{#id}` attribute syntax, both verified). So `HeadingIdentifiers` moves
  the shortcode, with the space that follows it, out of the heading's _text_ and
  into an inline HTML node: the renderer writes it out as it stands and the
  slugger does not read it. **359 headings move** (`:exclamation:` ×234,
  `:boom:` ×51, `:question:` ×25, `:checkered_flag:` ×24, `:classical_building:`
  ×17, `:space_invader:` ×6, `:gem:` ×2; every one of them opens its heading),
  and **no two headings collide** that did not already: the only post-strip
  duplicate, `Alice: check the state of branches` in
  `204-hello-github/exercise.md`, is written twice with the same shortcode today
  and already relies on the `-1` suffix. Only a shortcode opening the text or
  standing after a space is moved, which is what leaves a heading such as
  `Meeting at 10:30: what to bring` alone; a heading of nothing _but_ a
  shortcode keeps it, since there would otherwise be nothing left to slug. The
  **21 anchors the content links to** and the **10 in
  `server_help_component.ex`** have been updated with it — see [Heading
  references that compile-fail](#heading-references-that-compile-fail) — which
  means those links do not resolve under the Jekyll build that is still serving
  the site, and start working again at [Cutover](#cutover). Nothing 404s in the
  meantime: a stale fragment lands the reader at the top of the right page.
- **The navigation is read off the finished page, not built from the AST.** Both
  halves of an entry are only settled there. The identifiers are assigned while
  the document is rendered, and a heading a page repeats is numbered according
  to what came before it (`troubleshooting`, `troubleshooting-1`) — deriving
  them from the AST would mean writing the second slugger this section says is
  not needed. And a label is the heading as the page shows it, which is after
  the [passes over the finished page](#smaller-jekyll-plugins) have turned its
  shortcodes into images. This is also what `jekyll-toc` does, so the semantics
  come along for free.
- **The renderer's entries stop at the page.** `jekyll-toc` ran on the output of
  the _layout_, so today's navigation opens with the layout's own headings — `🏆
Graded exercise` and `:scroll: Legend` for an exercise, `Presentation` for a
  chapter with slides. Those move to the HEEx shell with the rest of the chrome,
  and so must their entries: the renderer returns the page's own headings, its
  opening included, and whatever lays the page out prepends what it draws
  itself. That shell is also what emits the markup `theme/src/toc.css` is
  written against — an entry is sized by `toc-h1`…`toc-h6`, which is why an
  entry carries its heading's level and not just its place in the tree. One to
  pick up with the [static build step](#static-build-step).
- **An entry keeps the heading's markup.** `jekyll-toc` replaced every element
  of a heading but an image by its text, so `### :boom: \`Uncaught
  PDOException\``lost its`<code>` in the navigation. The port keeps the
  heading's inline HTML as it is, which is one fewer rule and reads better.

### Smaller Jekyll plugins

Replace the remaining plugins:

- **`jekyll-target-blank`** — a trivial pass adding `target="_blank"` to
  external links, over the **finished HTML** rather than the Markdown document:
  184 links in 28 files sit inside block-tag bodies, which are already HTML by
  the time the page's document exists (see [Shared Markdown rendering
  core](#shared-markdown-rendering-core)). It must run on the **logical**
  references, before the [URL and link emission
  seam](#url-and-link-emission-seam) absolutizes content links: once a PDF build
  has rewritten internal links to `https://archidep.ch/…` they are
  indistinguishable from external ones by inspection.
- **`jekyll-seo-tag`** — move into the HEEx `<head>` (and the static layout's
  head for standalone mode).
- **`jekyll-feed`** — drop, or reimplement if the RSS feed is still wanted.
  Nothing links to `/feed.xml`; its only trace is the `{%- feed_meta -%}` call in
  `course/_includes/head.html`.

The fourth, **`jemoji`**, is done, and was not a port of the plugin.

#### One emoji vocabulary

**Decided and done: one closed registry and one emitter, rendering self-hosted
Twemoji SVGs, used by the course material and the application alike.**

The sweep that draws them is an HTML pass rather than an AST one because a tag
writes shortcodes into the wrapper around its body, which was never Markdown
(see [Shared Markdown rendering core](#shared-markdown-rendering-core)). Heading
IDs do not constrain the ordering: a heading's shortcodes are moved out of the
text the slugger reads before the page is rendered, so the sweep finds them
wherever it runs — see [TOC and heading anchors](#toc-and-heading-anchors). It
does, however, agree with `HeadingIdentifiers` on what a shortcode _is_: one
that opens the text or stands after a space.

Replacing `jemoji` is not the problem it looks like, because the plugin is not
where the mess is. Counted over both halves of the project, the emoji of this
course are decided in **six independent places**, in two spellings that do not
agree:

| Where                                                            | Spelling                                 | What                                                           |
| ---------------------------------------------------------------- | ---------------------------------------- | -------------------------------------------------------------- |
| Course content, 388 shortcodes                                   | `jemoji` → `<img>` hotlinked from GitHub | 11 distinct, mostly heading decoration                         |
| Course layouts (`chapter-title`, `sidebar`, `exercise`)          | literal Unicode                          | 🎬 🏆 🛠️ 📝 📖                                                 |
| Course search UI (`search.ts`, its templates)                    | literal Unicode                          | the same five, plus 🏠 🤷 🚀                                   |
| Course prose                                                     | literal Unicode                          | 🛠️ ×10, 🎉 ×4, 🍺 🍻 💙 💸 😭 🤔                               |
| The application (`core_components`, `layouts`, `dashboard_live`) | literal Unicode                          | 📚 💥 🎉 ⚔️ and the same five sidebar icons                    |
| The new renderer's own tags (`CalloutTag`)                       | both                                     | a literal 🛠️ beside its siblings' `:books:`, nine celebrations |

Two symptoms make the cost concrete. The `more` and `troubleshooting` notes are
the _same_ component on both sides, and their 📚 and 💥 are a GitHub CDN image
in the course and a system font glyph in the dashboard. And the trophy is
written `🏆` in the course layouts and `🏆️` in the application — the same emoji
with a variation selector on one side only, i.e. two different byte sequences
chosen independently in two files.

So the unit of work is the **vocabulary**, not the plugin:

- `ArchiDep.Emoji` — a pure registry of the ~34-emoji union of both sides,
  mapping a name to the character it stands for and the asset it is drawn from.
  It is **closed on purpose**: this vocabulary is small and _meaningful_
  (`:exclamation:` says "do this", `:boom:` says "here is what goes wrong"), and
  a closed set is what makes "the same emoji everywhere" reviewable instead of
  aspirational. Adding one is an entry plus an SVG.
- One emitter on that registry is the only code that knows what an emoji _looks
  like_ in HTML, which is what keeps the decision below reversible.
- Its consumers: the HTML pass over a finished page, the block tags' own icons,
  a HEEx component for the application, and a generated name→URL map for
  `search.ts` — the one consumer that lives in JavaScript and therefore has to
  be handed its URLs through the [seam](#url-and-link-emission-seam).

**Why images rather than Unicode**, given that the vocabulary is what matters
and either form would satisfy it:

- **The theme is already written against images.** `course.css`, `toc.css` and
  `slides.css` hang a heading's emoji into the left margin with `float` and a
  negative margin keyed on `img.emoji`, and the exercise legend does the same.
  That layout needs a box of known size; redoing it against font-sized spans is
  real work for a worse result. `theme.css` bundles the application's stylesheet
  with the course's, so the dashboard inherits the same rules for free.
- **A glyph is not the same picture everywhere.** Unicode means the course looks
  different on macOS, Windows and Linux — and several emoji in use (⚔️ 🏛️ 🛠️)
  are text-presentation codepoints that need a variation selector nobody applies
  consistently, which is exactly what the 🏆/🏆️ split is.
- **PDF generation stops depending on installed fonts.** `npm run pdf` drives
  Puppeteer; an image renders the same wherever Chrome runs.
- **It fixes a standalone-mode bug that already exists.** Every emoji of the
  site is currently an external request to `github.githubassets.com`, which
  contradicts the self-contained output [archival
  mode](#standalone--archival-mode) is supposed to produce. Self-hosting ~34
  SVGs makes those builds genuinely offline.

The assets are [Twemoji](https://github.com/jdecked/twemoji) SVGs, vendored from
the maintained fork at a pinned tag: GitHub's own emoji images derive from
Twemoji, so the course keeps the look it has today. The graphics are CC-BY 4.0,
which the project's own attribution note says a mention in a README satisfies.

**Rules the sweep has to keep**, beyond agreeing with `HeadingIdentifiers` on
what a shortcode is:

- **Code is not swept.** `jemoji` skips `<code>` and `<pre>`, and the content
  needs it to: `404-unix-basics/subject.md` alone holds six `/etc/passwd` lines
  such as `jde:x:1004:` that are shortcode-shaped by accident, and there are 66
  `:00:` timestamps and 18 `:--:` table separators elsewhere.
- **An unknown shortcode is left alone, in the body.** That leniency is what
  keeps those accidents working, and it is `jemoji`'s behaviour.
- **Both spellings converge.** The sweep rewrites the registry's own characters
  as well as its shortcodes, so prose that types 🍺 and prose that writes
  `:beer:` produce the same image and no content has to be normalised first.
- **An emoji outside the registry is reported.** This is what enforces the
  vocabulary rather than merely offering it. The check is deliberately narrow —
  a character in the pictographic blocks, or a symbol written with an explicit
  variation selector — so that ✓, ♯ and the arrows are never mistaken for
  decoration.
- **The pass is a scanner, not a DOM round-trip.** `Toc` already reads the
  finished page with regexes and the application has no HTML library outside the
  test environment; re-emitting every page through a parser would also put the
  [fidelity gate](#html-fidelity-gate) at the mercy of that parser's
  normalisation.

Two consequences worth stating before they surprise someone. The fidelity gate
needs this whitelisted: **every** emoji `src` changes, and the sites that are
Unicode today become images. And slides keep their Unicode for now — a deck is
never converted to HTML here, so its shortcodes are the [slides
task](#slides)'s to sweep over the Markdown it hands to reveal.js.

**Corrections while implementing:**

- **The registry is a top-level `ArchiDep.Emoji`, not part of `CourseSite`.**
  The dashboard's confetti is not course material, and making the application
  reach into the course renderer for it would put the dependency the wrong way
  round. Everything else about it is as described.
- **The sweep is a default of `RenderOptions`, not a pass a build opts into.**
  `html_passes` was designed as the seam a rewrite plugs into, but a build that
  configured passes and forgot this one would publish headings whose decoration
  was taken out of their identifiers for nothing — the same contradicting-itself
  state the plan keeps eliminating elsewhere. So the default list draws the
  emoji, exactly as `:tags` defaults to the tag table.
- **An emoji's alternative text is the character it draws.** A reader who cannot
  see the image is told which emoji it is by their own software, and a reader
  copying the page out of their browser gets the emoji back rather than
  `:books:` — which is what `jemoji` gave them.
- **The vocabulary came to 34**, not the eleven shortcodes the course writes:
  the five sidebar icons, the nine celebrations of a folded callout, ⚔️ and the
  spiral-eyed face of the dashboard, the six one-off emoji of the prose (🍺 🍻
  💙 💸 😭 🤔) and the three of the search dialog (🏠 🤷 🚀).
- **`.callout .icon.text` is gone from the theme.** It sized the one emoji a tag
  wrote as a character; with that written as a shortcode like its siblings,
  nothing emitted the class. `img.emoji` also gained a default size of `1.2em`
  seated on the baseline, so that an emoji outside the course's own layout — in
  the dashboard — is sized like the character it stands for rather than by its
  file.
- **A test asserts the registry is the only place under `app/lib` that writes an
  emoji character.** The course material has a sweep to enforce the vocabulary
  and the application has nothing of the kind, and it was the application that
  had drifted (`🏆` against `🏆️`).
- **The release image needed a copy of its own.** The digest stage took
  `assets/theme/` out of the theme build and nothing else, so the emoji would
  have been missing from production while working in development.
- **A tag names the emoji it shows.** `TagIcon` used to hold either a partial of
  the icon set or a piece of HTML the tag spelled out, and with emoji a thing of
  their own the second half no longer needs to be arbitrary: it is an emoji of
  the registry and, where the theme sizes the icon by its box, the class to wrap
  it in. Nothing a tag emits changed — the point is that `:hammr_and_wrench:`
  now fails the build where it used to reach the page as words.

The one consumer left out is the search dialog, whose icons are drawn by a
script rather than by the renderer and therefore need that map: a task of its
own, alongside the [search index](#search-index) work that produces what it
reads.

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

### Chapter document invariants

Two rules govern what a chapter directory may contain. They were implicit until
now — the [URL seam](#url-and-link-emission-seam) leaned on the first of them
without saying so — and they are **rules, not statistics**:

1. **A chapter has a subject or an exercise, never both.**
2. **An exercise never has slides.**

Today's corpus obeys both, checked over all 50 chapters: 19 subjects, 26
exercises, 5 slides-only chapters; 14 chapters carry slides and none of them is
an exercise. But the point is that a chapter breaking either rule is a **content
error to reject**, not a case to handle.

**Why the first rule is load-bearing.** A chapter's subject and its exercise are
emitted at the _same_ URL (`/course/402-run-virtual-server/`), which is only
coherent because at most one of them exists. Were both present, the build would
write two pages to one output directory, and their co-located images would
collide in the `PageAssetManifest` — which is keyed by output path precisely
because [an asset resolves against the page's output
directory](#page-adjacent-assets-are-digested). Neither failure is loud. So the
build must refuse the input rather than silently pick a winner.

The second rule has no such consequence today; it is enforced because it is
true, and because leaving it unenforced invites a `/course/<n>-<slug>/slides/`
page that nothing in the sidebar or the PDF conventions expects.

**Where the check goes: the step that enumerates the source tree** — [metadata
generation](#metadata-generation) — not the renderer. The renderer is handed one
document and never sees its siblings, so it is structurally incapable of
noticing either violation; putting the check where the chapter's files are first
listed is what makes it unmissable. Fail with **every** offending chapter
listed, not the first, so a bad restructuring is fixed in one pass.

**Consequences for the URL seam, which already assumes rule 1.**
`PageRef.identity/1` deliberately collapses a subject and an exercise into one
`{:chapter, num, slug}` identity, and that is sound only under the invariant —
otherwise the `/latest?to=…` resolver would be matching an identity that names
two documents. Nothing in the implemented seam changes; what changes is
that the assumption is now stated and checked at its source.

One sharp edge the invariant creates, and an argument for the [post-build link
check](#page-adjacent-assets-are-digested): `{% link %}` validates the _shape_
of a source path, not that the document exists. So `{% link
_course/402-run-virtual-server/subject.md %}` — a file that does not exist,
because that chapter is an exercise — resolves to the exercise's URL and emits a
working link to the wrong-named document rather than an error. Checking a link
target against the enumerated set of documents belongs with the same enumeration
step as the invariants themselves.

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

Today the app hardcodes brittle URL fragments into generated headings — **11 in
`app/lib/archidep_web/servers/server_help_component.ex`** (e.g.
`#create-your-server`,
`#i-forgot-to-open-some-or-all-of-the-ports-in-the-firewall`) plus one in
`app/lib/archidep_web/course/change_username_dialog_live.html.heex`
(`#how-do-i-change-my-username-usermod`). These silently break when a heading is
reworded.

Because we now parse the Markdown in Elixir, make **headings first-class** in
`Course.Material`: expose each referenced heading as a value the app links to
via a function/constant. A missing heading then fails compilation. This is the
single biggest robustness win of the migration and pairs with [TOC and heading
anchors](#toc-and-heading-anchors) (which produces the stable IDs) and [A richer
Course.Material model](#a-richer-coursematerial-model).

Nine of the 10 distinct fragments the app hardcodes are reproduced verbatim by
the MDEx slugger; the tenth, `#how-do-i-change-my-username-usermod`, is a
cheatsheet heading and equally unaffected. What did move is the **emoji
shortcode** each of the `server_help_component.ex` fragments used to carry, so
those strings have already been rewritten (`#exclamation-create-your-server` →
`#create-your-server`) — see [TOC and heading
anchors](#toc-and-heading-anchors). This task stays a pure robustness change on
top of that: no further anchor has to move, and no redirect is needed.

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

**Not every surface that _can_ read the status _should_.** The home page's
"Previously" / "Due next" / "Next time" cards are hidden outright in an
`:archive` build, whatever the source reports — a finished year has no "next
time" — so the archival chrome policy overrides the source rather than being
driven by it. See [Standalone / archival mode](#standalone--archival-mode).

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

**Dashboard-free is derived from `mode`, not a fourth knob.** Today the flag is
set by the GitHub Pages config, so "standalone" and "hosted on Pages" are the
same thing. Under the per-year model they are not: an `:archive` build is served
from **both** hosts ([Archived years: a banner and one dynamic
resolver](#archived-years-a-banner-and-one-dynamic-resolver)), and a past year
has no dashboard on either. So the chrome policy is a function of `mode` —
`:live` carries the dynamic chrome, `:backup` and `:archive` do not — and must
never be keyed off the host or the base path. This is the same correction as
`home_at_base?` in the [configuration knobs](#configuration-knobs): a knob that
is a function of `mode` in every row of the [consumers
table](#consumers-as-configurations) is a representable state that can
contradict itself.

**What "dynamic chrome" covers**, enumerated from the Liquid templates so the
port inherits an explicit list instead of a flag whose meaning is spread over
five `{% unless %}` blocks: the header's login button and profile dropdown, the
sidebar's app-navigation icon submenu (below), the status/CI badges on the home
page, and the PDF download links in the "On this page" aside. The last one stops
being a `mode` question at all: whether a page offers a PDF link becomes "does
`PdfManifest` have a location for this page" ([Generated PDFs may live
anywhere](#generated-pdfs-may-live-anywhere)), which is exactly why the archived
years can keep their PDFs ([Per-year PDF archive](#per-year-pdf-archive)).

**Archival mode hides the home page's progress cards unconditionally.** The home
page shows three session-relative cards — "Previously", "Due next", "Next time"
— built from the progress source ([Progress: structure vs
status](#progress-structure-vs-status)). In `:archive` they are **not rendered
at all**, regardless of what the source reports. This must be expressed as a
chrome rule and not left to fall out of the data: the final archive's
all-complete snapshot would otherwise emit a "Previously" card listing the whole
course and drop the other two by emptiness — plausible-looking output that
nobody decided on. "What is due next" is a statement about a course in progress;
a finished year has no such thing to say. The sidebar's progress borders need no
equivalent rule — an all-complete snapshot colours every chapter `done`, which
is an accurate statement about a finished year.

**The sidebar's icon submenu exists only in `:live`.** The small icon menu above
the chapter list holds exactly three entries — Course (the home page), Dashboard
(`/app`) and Admin (`/admin`, revealed by `course/src/assets/course.ts` when the
session flag says root) — and its only purpose is switching between the static
course and the dynamic app; the only script touching it toggles the admin
entry's visibility. Every dashboard-free build therefore omits the whole `<ul>`
and its wrapper, not just its dynamic entries: what the standalone flag leaves
behind today is a **one-item menu** whose sole entry duplicates the header logo
link (and the mobile sidebar logo), both of which already resolve to `{:home}`.
`:backup` drops it for the same reason `:archive` does, and then some — the
backup copy exists precisely for when the app is unreachable, so a Dashboard
link there points at the thing that is down.

The progress cards are **not** symmetric with the submenu: they stay in
`:backup`, because the backup tracks the live progress source, so "due next" is
still true there. So the two rules are keyed differently on purpose — the
submenu is `:live`-only, the cards are hidden in `:archive` only.

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
  at a dynamic resolver in the app (`/latest?to=…`). The unprefixed legacy paths
  (`/course/…`, `/cheatsheets/…`) are that same rule applied to the one
  unprefixed edition: they 301 into `/2025/…` and get the banner, rather than
  being resolved away — see [Archived years: a banner and one dynamic
  resolver](#archived-years-a-banner-and-one-dynamic-resolver).

### Decouple PDF generation from production

**Goal: `npm run pdf` should run against a local build, not the deployed
production website, while the links inside the PDFs still point to production
URLs.** Today `pdf.ts` is pointed at `https://archidep.ch` because that is the
only way to get production URLs into the exported PDFs — a constraint that ties
an expensive step to the live site, and the reason that step is still run by a
human rather than by CI.

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
working offline and able to regenerate a past year's PDFs from that year's
frozen archive.

**That is the prerequisite for the actual goal: PDF generation belongs in CI.**
A step that needs the production site up cannot run unattended, which is why the
export is human-triggered today and why the uploads that follow it are manual.
Once it consumes an artifact, the CI job is the ordinary shape — build, serve it
locally, print, publish — and the publish step feeds the resulting locations
back through `PdfManifest` ([Generated
PDFs](#generated-pdfs-may-live-anywhere)), whose `{:external, base}` base and
`{:url, …}` overrides exist for exactly that handoff. Note that agents must
still not run `npm run pdf` locally (see [`AGENTS.md`](../AGENTS.md)); that is a
cost-control rule about this working copy, not a statement about the end state.

It composes with the
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
archived `/2025/` site and its PDFs travel together.

The convention has to be one **CI** can write to, since that is where generation
and publication end up once [the export no longer needs the production
site](#decouple-pdf-generation-from-production) — an archive whose PDFs still
depend on someone remembering to upload them is an archive that will eventually
be missing them. (Do **not** run `npm run pdf` from this working copy — it is
expensive and human-triggered per project policy.)

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

**The dialog draws its own icons, and they are the site's emoji.**
`course/src/assets/course/search.ts` maps a result's type to one of five
characters — 📝 🛠️ 🏆 🎬 📖 — and its two templates write a 🚀 and a 🤷 of their
own. They are the same emoji the sidebar shows next to the same documents, so
they must be the same picture: the [emoji vocabulary](#one-emoji-vocabulary) is
enforced everywhere else and this is the last place it is not. The one thing
that makes it more than a substitution is that a client cannot work out where an
emoji file is — only the build knows the digested names — so the build hands it
a generated name→URL map, the same one any other script would need.

### HTML fidelity gate

The gating QA step — but the bar is **functional and visual parity, not
byte-identical HTML**. What must hold across all 59 course docs + 4 cheatsheets
(and the slides): nothing is broken — links resolve, tags render, code
highlights, TOC/anchors work, navigation and progress classes are correct — and
each page **looks good**. Four divergences are **known and expected**, so look
for them deliberately rather than treating them as regressions: code blocks
restyled from rouge to `lumis`, lone raw `<img>` lines no longer wrapped in
`<p>`, the `cols` column classes finally applying (see [Spike
results](#spike-results)), and the **359 heading identifiers that drop their
emoji shortcode** — with the 31 links that name them, which do not resolve under
Jekyll and must resolve here (see [TOC and heading
anchors](#toc-and-heading-anchors)). We explicitly **do not** require pixel- or
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
| `{% highlight %}`                                                              | 0 (was 2)              | Now decorated fenced code      |
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
- PDF generation (Puppeteer drives the rendered site) — the _mechanism_ stays as
  it is; what changes is what it is pointed at and who runs it, so that it can
  move into CI ([Decouple PDF generation from
  production](#decouple-pdf-generation-from-production)).
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
