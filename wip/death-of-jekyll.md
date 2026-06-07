# Feasibility of Elixir-native course rendering

An evaluation of replacing the Jekyll static-site generator (`course/`) with an
Elixir-native rendering step inside the Phoenix application.

**Headline:** This is not "reimplementing Jekyll." The surface this course
actually uses is small and clean, and the codebase is already half-way there.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [What the course actually depends on (measured, not assumed)](#what-the-course-actually-depends-on-measured-not-assumed)
- [The decisive point: half of this is already rendered in Elixir](#the-decisive-point-half-of-this-is-already-rendered-in-elixir)
- [What gets simpler, and what is load-bearing](#what-gets-simpler-and-what-is-load-bearing)
- [The honest hard parts / risks](#the-honest-hard-parts--risks)
- [An architectural fork worth deciding early](#an-architectural-fork-worth-deciding-early)
- [Verdict and suggested path](#verdict-and-suggested-path)

<!-- END doctoc -->

---

## What the course actually depends on (measured, not assumed)

The content is ~28,400 lines of Markdown across **59 course files + 4
cheatsheets + 14 progress files**, organized into 8 sections. The
Jekyll-specific surface inside that content is remarkably thin:

| Construct                                                                      | Uses in content        | Nature                      |
| ------------------------------------------------------------------------------ | ---------------------- | --------------------------- |
| Custom block tags (`note`/`callout`/`cols`/`solution`/`mermaid`)               | 317 / 95 / 24 / 23 / 1 | Own ~50–120-line Ruby files |
| `{% include icons/… %}`                                                        | 44 (all icons)         | SVG inlining                |
| `{{ … \| relative_file_url }}`                                                 | 22                     | Per-page asset URLs         |
| `{% highlight %}`                                                              | 2                      | Could be plain fenced code  |
| **General Liquid logic** (`if`/`for`/`assign`/`capture`/`case`) **in content** | **0**                  | —                           |
| kramdown attribute lists `{:.foo}`                                             | 0                      | —                           |
| Footnotes / definition lists                                                   | 1 / 0                  | negligible                  |

Code fences are all standard languages (`bash` ×756, `yml`, `nginx`,
`Dockerfile`, `php`, …). **The content is essentially CommonMark + GFM plus six
well-defined custom block constructs.** There is no general-purpose templating
logic embedded in the prose — that all lives in layouts/includes, which are the
part you would rewrite as HEEx anyway.

---

## The decisive point: half of this is already rendered in Elixir

The strongest argument. The app does **not** treat the course as a black box:

- `app/lib/archidep/course/helpers/material_helpers.ex` reads `archidep.json`
  **at compile time** and `material.ex` exposes `course_sections/0` /
  `course_cheatsheets/0`.
- `app/lib/archidep_web/components/layouts/app.html.heex` (≈ lines 184–279)
  **re-renders the entire sidebar in HEEx** from that JSON — iterating the same
  sections, applying the same `border-r-4 border-success/50` progress classes,
  the same icons.

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
   cutover. Budget real time here.

2. **The custom block tags.** Do not migrate the _content_ syntax. The pragmatic
   path is a small Elixir preprocessor that recognizes `{% note … %}…{% endnote
%}` (and the five siblings), renders the inner Markdown with MDEx, and emits
   the same HTML the Ruby tags emit today. That is a direct port of ~6 short
   files and **zero content edits**. (A pure-Elixir Liquid lib, `Solid`, exists,
   but custom block tags with Markdown-inside are fiddly — a targeted
   preprocessor is simpler and faster.)

3. **Reference-link resolution.** The Ruby `utils.rb` copies bottom-of-doc
   `[ref]: url` definitions into each extracted tag block and into slides so
   reference links survive extraction. You would reproduce that helper in Elixir
   (small, but do not forget it — it is load-bearing for links inside
   notes/callouts and slides).

4. **TOC + heading anchors.** `jekyll-toc` + the `toc_only` filter produce the
   "On this page" nav and heading IDs. You would generate IDs and build the TOC
   from the MDEx AST. Modest, well-trodden work.

5. **Smaller Jekyll plugins to replace:** `jemoji` (`:rocket:` shortcodes —
   used in titles _and_ in tag output like `:books:`; needs a shortcode→emoji
   map), `jekyll-target-blank` (trivial AST pass), `jekyll-seo-tag` (HEEx
   `<head>`), `jekyll-feed` (drop or reimplement).

6. **Slides.** reveal.js renders slide Markdown **client-side** — Jekyll only
   pre-expands Liquid into `raw_markdown`. So slides need the tag/asset
   preprocessing step but **not** the Markdown→HTML step. Easy to get wrong if
   you assume slides are server-rendered.

7. **Standalone/archival mode** (`_config.pages.yml` → GitHub Pages) must still
   produce fully static, dashboard-free HTML. A static Elixir build step
   preserves this; just keep the `standalone` flag semantics.

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
runtime mode is possible.

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
