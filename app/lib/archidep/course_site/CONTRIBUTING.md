# Contributing

This document describes the **course material site** subsystem
(`ArchiDep.CourseSite`) of the ArchiDep dashboard application. It is part of the
application documented in the [`app/CONTRIBUTING.md`][app-contributing] file at
the application root, which covers the overall architecture, coding guidelines
and tooling that also apply here. Read that document first.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Overview](#overview)
- [Why this is not a bounded context](#why-this-is-not-a-bounded-context)
- [Identities](#identities)
- [URL and link emission](#url-and-link-emission)
  - [What a build is](#what-a-build-is)
  - [Reference kinds and their policy](#reference-kinds-and-their-policy)
  - [Assets co-located with a page](#assets-co-located-with-a-page)
  - [Generated PDFs](#generated-pdfs)
  - [Errors](#errors)
- [Rendering](#rendering)
  - [Every tag body is its own Markdown document](#every-tag-body-is-its-own-markdown-document)
  - [Passes: over the document, or over the page](#passes-over-the-document-or-over-the-page)
  - [The opening of a page](#the-opening-of-a-page)
  - [Slides are not converted](#slides-are-not-converted)
  - [Reporting rather than raising](#reporting-rather-than-raising)
  - [Known differences from what Jekyll produces](#known-differences-from-what-jekyll-produces)
- [Testing](#testing)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

---

## Overview

This subsystem renders the [course material
site](../../../../course/CONTRIBUTING.md) — the chapters, cheatsheets and slides
that make up most of the website — and writes it as a set of static files.

It is **pure and self-contained**: no database, no processes, no Phoenix. A
build is a function of its inputs, which is what lets the same code produce the
live site, a backup copy hosted elsewhere, a frozen archive of a past edition,
and the build printed to PDF.

## Why this is not a bounded context

`ArchiDep.CourseSite` deliberately sits **outside** the [bounded
contexts][bounded-contexts] and has none of their anatomy — no facade, no use
cases, no schemas, no policy, no events. Those exist to own tables and authorize
access to them; this subsystem owns no state and answers no requests. Keeping it
apart also keeps it honest: it must run standalone, so a stray `Repo` or
`Endpoint` call in here is visibly wrong rather than merely unfortunate.

The relationship to the [`Course` context](../course/CONTRIBUTING.md) runs one
way. `ArchiDep.Course.Material` is a compiled model of the course _structure_
that the dashboard links into; it is built from what this subsystem parses, and
it stores the [identities](#identities) defined here rather than URLs, so no
edition of the course is baked into the compiled module.

## Identities

Two modules define how a page of the site is referred to, without naming a URL:

- [`DocumentRef`](./document_ref.ex) — a course document: a chapter number, a
  slug and a type (`:subject`, `:exercise` or `:slides`). Its
  `parse_source_path/1` is the single place that knows the layout of the content
  directory, including the two ways slides may be written (`slides.md` at the
  chapter root, or `slides/slides.md`), which are one document with one URL.
- [`PageRef`](./page_ref.ex) — anything with a page URL: the home page, a
  document or a cheatsheet. `output_path/1` is where that page lives inside a
  build, with no mount point and no edition prefix.

A page URL identifies a page **less** precisely than a reference does: a
chapter's subject and its exercise are emitted at one and the same URL.
`PageRef.identity/1` is that weaker identity and `parse_output_path/1` recovers
it from a path — enough to match an archived page against the current edition of
the course.

That collapse is safe only because of a rule the content obeys: **a chapter has
a subject or an exercise, never both, and an exercise never has slides.** Two
documents at one URL would otherwise be written over each other, and their
co-located assets would collide in the `PageAssetManifest`, which is keyed by
output path. The renderer cannot check this — it is handed one document and
never sees a chapter's other files — so the check belongs to whatever enumerates
the content directory, and it must reject the input rather than choose between
the two.

## URL and link emission

[`Urls`](./urls.ex) is the **only** place in the rendering pipeline allowed to
build a URL. Everything else emits a logical reference — "the exercise of
chapter 402", "the image next to this page" — and gets a string back.
Concatenating a prefix onto a path anywhere else is a bug: it is how a
deployment ends up with four subtly different opinions about where the site is
mounted.

That indirection buys three things: a reference to something that does not exist
is an error rather than a silent 404; the compiled course model stores
references instead of URLs; and every deployment becomes a configuration rather
than a variation of the renderer.

### What a build is

A [`UrlContext`](./urls/url_context.ex) is one build. Its `mode` says what the
build _is_ — `:live`, `:backup` or `:archive` — and the rest says where it sits:
`base_path` (the mount point), `version` (the edition, i.e. the starting year of
the academic year), `build_id`, `absolute_base_url`, `live_site_url` and the
three manifests.

The mount point and the edition are **separate knobs** rather than one prefix
because the home page needs the mount point on its own: while an edition is
being taught its home page sits at the mount point, and it moves under the
edition prefix once archived. That rule is derived from `mode`, not stored, so a
build cannot claim to be both.

`build_id` exists because the search index cannot be named after its own
content: it is built _from_ the rendered pages whose `<head>` has to name it.
Naming it after the build's _inputs_ breaks the cycle, which is what separates
`{:build_file, path}` from `{:site_file, path}`.

### Reference kinds and their policy

`Urls` documents the full table; the two rules worth knowing before touching any
of it:

1. **Content links may be absolutized; assets never are.** Only the PDF export
   sets `absolute_base_url`, so a build can be served from a throwaway local
   server and still print links to the main site — with its stylesheets and
   images loading locally.
2. **Assets co-located with a page stay relative to that page**, so no knob
   touches them at all: they are immune to the mount point, the edition prefix
   and the origin alike.

A fragment within the page being rendered stays a bare `#id`, so navigation
inside a page — or inside an exported PDF — never leaves it.

### Assets co-located with a page

An author writes `![CLI](images/cli.jpg)` next to a page and the build digests
the file. Two consequences to keep in mind when working on this:

- **The reference resolves against the page's _output_ directory**, never its
  source directory. Slides written at a chapter's root are output one segment
  deeper than they are written, so `../images/x.jpg` in such a file means the
  chapter's `images/` directory — which is true output-relative and false
  source-relative. The manifest is therefore keyed by output path, and
  [`PageAssetManifest`](./urls/page_asset_manifest.ex) holds the digested **file
  name** only, since digesting renames a file and never moves it.
- **The author's own path shape is preserved**: only the last segment changes,
  so `../images/x.jpg` stays `../images/x-<digest>.jpg`. A missing file is a
  build error, because resolving requires the manifest entry that only a real
  file produces.

### Generated PDFs

The slides' and cheatsheets' PDFs are generated by a separate step — today run
by a human, in the end state a CI job — which is why this subsystem is told
where they are rather than deciding. [`PdfManifest`](./urls/pdf_manifest.ex)
says where they are published: `:site` (under the build's own prefix) or
`{:external, base}` (a bucket, a release — anywhere the server does not have to
store them). An entry may also be a `{:url, url}` override, for a host that
renames what it is given and therefore publishes at a URL that cannot be derived
from the local file name.

A page whose PDF has not been published resolves to `{:error, {:unknown_pdf,
_}}`. Unlike a missing image, that is **not** necessarily a build failure: a
chapter may simply not have been exported yet, and the caller is expected to
leave the download link out. This stays true once the export is automated, since
the PDFs are printed _from_ a build — new content is always rendered at least
once before its PDF exists.

### Errors

`resolve/3` returns `{:ok, url}` or `{:error, reason}`; `resolve!/3` raises a
[`UrlError`](./urls/url_error.ex). Use the tuple where a failure is a fact about
the content — a renderer turns it into an error naming the offending tag, and
the build collects every broken reference of a document rather than stopping at
the first. Use the bang where a failure is a programmer error, such as the
application's own navigation. Both render their message with `format_error/1`,
so there is one wording for the same problem wherever it surfaces.

## Rendering

[`Renderer`](./renderer.ex) turns one source file into what the site serves for
it. A document goes through **two stages**, the same two Jekyll uses: the Liquid
of the whole document is expanded first
([`Renderer.Liquid`](./renderer/liquid.ex)), and what comes out is then
converted from Markdown ([`Renderer.Markdown`](./renderer/markdown.ex)). The
order is what lets a tag produce Markdown and have it converted like the rest of
the page.

A build hands the renderer a [`RenderContext`](./renderer/render_context.ex) —
one document, which page of which build it is — and gets back a page or a list
of what is wrong with it. Nothing reads a file: the partials a document may
include are parsed by `Renderer.compile_includes/1` and passed in, so a render
is a function of its inputs like the rest of the subsystem.

### Every tag body is its own Markdown document

A block tag converts its own body, rather than emitting Markdown for the page's
conversion to pick up later. That is not a stylistic choice: a tag wraps its
body in HTML, and CommonMark treats the content of a raw HTML block as opaque,
so a single conversion of the whole page would leave the inside of every note
and callout unconverted. Jekyll converts tag bodies separately for the same
reason.

Two consequences for anyone writing a tag:

- **Read the body with the right helper.** A body of prose is parsed as Liquid
  ([`NestedBody`](./renderer/liquid/nested_body.ex)) because the course's notes
  and callouts contain `{% link %}` tags; a body of code is captured verbatim
  ([`RawBody`](./renderer/liquid/raw_body.ex)) so that a `{{` in a shell sample
  is a sample. A tag whose markup contains a path reads it with
  [`RawMarkup`](./renderer/liquid/raw_markup.ex), since Liquid's lexer rejects
  an unquoted slash.
- **Emit no blank line.** A blank line ends an HTML block in CommonMark, so a
  blank line inside a tag's wrapper would have the rest of that wrapper parsed
  as Markdown. The output of `Renderer.Markdown` never contains one; only
  hand-written wrappers can.

### Passes: over the document, or over the page

Two seams rewrite what the renderer produces, and which one a rewrite belongs to
is decided by what it needs to see:

- An [`AstPass`](./renderer/ast_pass.ex) runs over **every** Markdown document
  the build converts, a page and a tag body alike. Rewriting the URL of an image
  belongs here.
- An [`HtmlPass`](./renderer/html_pass.ex) runs **once**, over the finished HTML
  of a page. Anything that has to see inside a tag's output belongs here, since
  a tag's body is one opaque node by the time the page's document exists.

Emoji shortcodes are the sharp case: heading identifiers are slugged from the
heading's text as it is rendered, and the course links to headings such as
`#exclamation-create-your-server`. Replacing the shortcode before rendering
would move every one of those anchors, so it can only be an `HtmlPass`.

### The opening of a page

A page comes back in two pieces, because the site shows its opening above the
table of contents and the rest below. [`Excerpt`](./renderer/excerpt.ex) splits
the parsed document at the `excerpt_separator` the front matter declares, or
after the first block when it declares none.

Splitting the document rather than the text is what makes this safe: reference
links are already resolved when the document is parsed, so both pieces keep
working, and a separator written inside a code block is a code block rather than
a place to cut. Jekyll instead renders the opening twice and deletes one copy
from the other by string match, which fails silently whenever anything in the
opening renders differently the second time.

Declaring a separator the document never writes is an **error**, not a third way
of cutting a page: the author asked for a boundary and left it out. The page is
still cut after its first block so that the rest of its problems are reported in
the same pass, per [Reporting rather than
raising](#reporting-rather-than-raising). Jekyll instead makes the whole page
the opening, which is why the documents doing this today read as if their
opening were the entire page.

### Slides are not converted

A deck is converted in the browser: reveal.js splits it into slides and converts
each one. So `Renderer.render_slides/1` stops after the Liquid stage and hands
back Markdown.

That is also why a deck's link reference definitions are **substituted into it**
rather than appended to it, as they are for a page: the definitions sit at the
bottom of the file, and every slide but the last would be converted without
them.

### Reporting rather than raising

A document that refers to a chapter that does not exist, an image that is not
there or a partial that was never given to the build produces a page **and** a
list of [`RenderError`](./renderer/render_error.ex)s. Only a document that does
not parse produces nothing.

So a tag renders what it can and calls
[`Registers.report/2`](./renderer/liquid/registers.ex); a pass returns its
errors alongside its result; a filter returns `{:error, exception, fallback}`,
which is the contract `Solid` expects and the reason a render error is an
exception. An error naming a URL delegates its wording to `Urls.format_error/1`,
per [Errors](#errors) above.

`Registers` is also the only thing that knows the key the rendering context
lives under in `Solid`'s registers. Anything a tag needs to produce besides HTML
— identifiers to check for duplicates, say — belongs there too rather than as a
new field of `RenderContext`, which is built once per document and never
updated.

### Known differences from what Jekyll produces

The bar is a page that reads correctly and looks right, not identical markup.
Two differences are known and expected rather than regressions:

- A heading carries an anchor element (`<h2 id="…">Text<a class="anchor"></a>`)
  that kramdown does not emit. The identifier itself is the same — verified
  against every heading of every course document.
- Code blocks are not highlighted yet. MDEx highlights through
  [`lumis`](https://hex.pm/packages/lumis), which emits different markup from
  the `rouge` classes the theme is written against; enabling it is part of the
  theme's own migration.

## Testing

Everything here is pure, so tests are plain `ExUnit.Case, async: true` with
doctests for the self-evident functions, following the [testing guide][testing].
Two specifics for this subsystem:

- `Urls` is covered per reference kind **and** by a block asserting every kind
  at once under each configuration a build is really published under. The
  per-kind tests localise a failure to one kind; the configuration block is the
  only place knob _interactions_ are pinned, and its expectations are written by
  hand from the emission table rather than from the code's output.
- The claims that later work depends on are pinned as [property-based
  tests][properties]: that an asset next to a page is unaffected by how the
  build is published, that a global asset is never absolutized, that the
  identity round-trips hold, and that rendering a parsed document is rendering
  the Markdown — the premise the pass seams rest on. Generators live in
  [`CourseSiteFactory`](../../../test/support/course_site_factory.ex).
- The renderer is driven by the tags and passes in
  [`CourseSiteRendererTestTags`](../../../test/support/course_site_renderer_test_tags.ex)
  rather than by the course's real ones, so that a test of the pipeline does not
  depend on what any particular tag happens to emit. They are also the worked
  example of the tag contract described above.

[app-contributing]: ../../../CONTRIBUTING.md
[bounded-contexts]: ../../../CONTRIBUTING.md#bounded-contexts
[properties]: ../../../docs/testing.md#property-based-tests
[testing]: ../../../docs/testing.md
