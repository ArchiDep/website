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
- [Building](#building)
  - [Checking it against the real content](#checking-it-against-the-real-content)
- [Rendering](#rendering)
  - [Every tag body is its own Markdown document](#every-tag-body-is-its-own-markdown-document)
  - [The tags the course writes](#the-tags-the-course-writes)
  - [Naming what a page renders](#naming-what-a-page-renders)
  - [Passes: over the document, or over the page](#passes-over-the-document-or-over-the-page)
  - [One emoji, one picture](#one-emoji-one-picture)
  - [A link that leaves the site opens elsewhere](#a-link-that-leaves-the-site-opens-elsewhere)
  - [What a page says about itself](#what-a-page-says-about-itself)
  - [A heading is identified by what it says, not by its decoration](#a-heading-is-identified-by-what-it-says-not-by-its-decoration)
  - [The navigation of a page](#the-navigation-of-a-page)
  - [Colouring a code block](#colouring-a-code-block)
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
and the build printed to PDF. [`Build`](./build.ex) is the single exception and
the only module here that touches the filesystem — see [Building](#building).

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
the two. [`ContentTree`](./build/content_tree.ex) is that enumeration and where
both rules are enforced, along with the two other ways a chapter can turn out
not to be one chapter: a document written twice — the two slides layouts are one
identity — and a number used by two directories, which are two pages by URL but
one chapter to anything that records progress against a number.

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
- **An image is a file and a link may be one.** An image the build has no file
  for is a page showing a picture that is not there, and is reported. A link is
  written the same way whether it points at a file or at another page of the
  course — `dns-configuration.md` and `../cli/` are both links a chapter writes
  — so one that resolves to no file is taken to be a link to a page and left
  exactly as written.
- **Resolving twice is resolving once.**
  [`PageAssetManifest`](./urls/page_asset_manifest.ex) knows an asset by the
  name it is written under _and_ by the name it is published under, so a
  reference that has already been resolved resolves to itself. That is what
  makes the rewrite safe to run where it cannot be run exactly once: a tag body
  is converted during the Liquid stage, so the images in it are resolved there,
  and the tag's finished HTML then re-enters the page as one node the page's own
  rewrite reads again. The 22 references the content writes with
  `relative_file_url` are the same story. Nothing needs to remember what has
  already been done — which is the point, since a marker would have to survive
  being handed to a browser as text.
- **A page asset's file name has to be URL-safe** (`[A-Za-z0-9._-]`), because
  the second lookup of the rule above is by the emitted path: a name needing
  percent-encoding would resolve once and then fail to be found. Every file in
  the course is named that way today, and the step that copies and digests them
  is where to keep it that way.

Two places do the rewriting, because a reference is written in two kinds of
thing. [`PageAssets`](./renderer/page_assets.ex) is an
[`AstPass`](#passes-over-the-document-or-over-the-page) over the URL of every
image and every link of a document;
[`AssetReferences`](./renderer/asset_references.ex) is the scan of text it
delegates to for the raw HTML a document embeds, and the one a
[deck](#slides-are-not-converted) uses for the whole of itself.

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

## Building

[`Build`](./build.ex) is the **only** module of this subsystem that reads or
writes a file. Everything else is a function of its inputs, which is what lets
one build produce the live site, a backup copy, a frozen archive and the PDF
export; keeping the filesystem in one named place is what makes that checkable
rather than merely intended. So what is left in `Build` is fetching bytes and
putting them somewhere, and each rule of a build lives in a pure module beside
it, documented there rather than here:

| Module                                            | What it decides                                                                                |
| ------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| [`ContentTree`](./build/content_tree.ex)          | what each file of the content directory is, where it is published, and what a chapter may hold |
| [`PageAssetDigest`](./build/page_asset_digest.ex) | what a published file is called                                                                |
| [`AssetDigest`](./build/asset_digest.ex)          | where the global assets went, per `phx.digest`                                                 |
| [`LinkCheck`](./build/link_check.ex)              | which of a finished build's links lead nowhere                                                 |

Three things about the shape of it are worth knowing before reading any of them.

**Naming a file and writing it are separate.** What a file is called follows
from its content, so `page_asset_manifest/2` answers that by reading alone and
`publish_page_assets/4` does the copying. A caller that only needs to resolve
references — the check below, and anything that renders without publishing —
never names a directory to write into, and therefore cannot be pointed at the
wrong one.

**Reading comes before writing.** Every file a build publishes is read and the
whole manifest settled before any of them is written, so a content directory
that is going to be rejected never leaves half a build behind. That is also what
lets the eventual publish path render into a temporary directory and swap it
into place.

**Failures are collected.** A build reports every offending file rather than
stopping at the first, the same way [a document reports all of its
problems](#reporting-rather-than-raising) — otherwise a content directory takes
as many runs to fix as it has mistakes.

### Checking it against the real content

`mix archidep.course_site.assets` builds both manifests from the real content
and the real assets and renders every document against them, so that a reference
no longer resolving is a command anyone can run rather than something noticed
once. It writes nothing.

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

### The tags the course writes

Six block tags wrap prose in the HTML the theme styles:

- [`note`](./renderer/liquid/note_tag.ex) (an aside)
- [`callout`](./renderer/liquid/callout_tag.ex) (something not to skip)
- [`cols`](./renderer/liquid/cols_tag.ex) (a row of columns)
- [`solution`](./renderer/liquid/solution_tag.ex) (a collapsed answer)
- [`markdown`](./renderer/liquid/markdown_tag.ex) (a piece converted where the
  page would not convert it)
- [`mermaid`](./renderer/liquid/mermaid_tag.ex) (a diagram).

They are registered in [`Tags`](./renderer/liquid/tags.ex) alongside the two
inline ones, `link` and `include`.

Three rules run across all of them:

- **What a tag's markup means is worked out when it is parsed; what it could not
  mean is reported when it renders.** Markup that is not a `key: value` list at
  all is a parse error, since there is nothing to render. A value the tag cannot
  use is not: an aside of an unknown kind is shown as a plain note, a row of
  thirteen columns as a row of two, and the value the author wrote is reported.
- **A tag emits no whitespace of its own**, for the reason [every tag
  body](#every-tag-body-is-its-own-markdown-document) is its own document: a
  blank line ends an HTML block. The one exception is `mermaid`, whose body may
  contain blank lines and is therefore emitted inside a `pre` element, which
  CommonMark reads to its closing tag rather than to the next blank line.
- **A tag names the emoji it shows** rather than spelling out its shortcode, so
  that an emoji the site does not have fails the build instead of reaching a
  page as words. What it writes is the shortcode a page would write, left for
  the sweep of the finished page to draw — see [One emoji, one
  picture](#one-emoji-one-picture).

Neither kind of icon is written out as markup: a tag holds either an emoji of
the site or the name of an `icons/…` partial — the same one the content includes
by hand — and [`TagIcon`](./renderer/liquid/tag_icon.ex) renders both.

### Naming what a page renders

A folded `callout` — the `more` kind, which a page keeps folded until the reader
asks — is the one thing a tag names: the fold is a checkbox and its labels, and
they find each other by an identifier. Two of them under one name would pair the
wrong label with the wrong input, so a tag asks
[`Registers`](./renderer/liquid/registers.ex) what is already taken before
settling on one. A name that is missing, malformed or taken is replaced by a
positional one and reported, so that the page still folds while the build fails
over the name.

The identifier the author writes only has to be meaningful within a chapter: the
page is prefixed to it. What that prefix is comes from the
[`PageRef`](./page_ref.ex), which is why it is a name and not the empty string
it used to be for a cheatsheet.

Whatever else such a callout renders is **derived from that identifier**, never
drawn: the label that folds it back up congratulates the reader in one of eight
wordings, and picking one at random would mean a build was not a function of its
inputs.

### Passes: over the document, or over the page

Two seams rewrite what the renderer produces, and which one a rewrite belongs to
is decided by what it needs to see:

- An [`AstPass`](./renderer/ast_pass.ex) runs over **every** Markdown document
  the build converts, a page and a tag body alike. Rewriting the URL of an image
  belongs here, and [`PageAssets`](./renderer/page_assets.ex) is the pass that
  does it: what a document refers to is written in the document, and by the time
  a page's HTML exists a code sample has become markup a rewrite would have to
  learn to tell apart again.
- An [`HtmlPass`](./renderer/html_pass.ex) runs **once**, over the finished HTML
  of a page. Anything that has to see inside a tag's output belongs here, since
  a tag's body is one opaque node by the time the page's document exists.

Emoji shortcodes are the case that shows the difference: a tag writes them in
the wrapper it puts around its body, which was never Markdown at all, so a
rewrite of the document would leave those alone and turn only the page's own
into images.

A rewrite a **deck** needs is neither, since a deck has no document and no page
of its own. Those are called straight from `render_slides/1`, the way
[highlighting](#colouring-a-code-block) is, and for the same reason: with no
seam to be a default of, being optional could only mean being forgotten.

Both seams and both sweeps read text with [`Sweep`](./renderer/sweep.ex), which
cuts a fragment into the parts a rewrite may touch and the parts it may not.
Which regions are protected is the rewrite's to choose, and the two choose
differently: an emoji is written in a page's words, so every tag is protected
from it, while the URL of an image is written in a tag's attributes, which is
the whole reason that sweep is looking. A deck adds what Markdown writes code
with — a fence, a backtick — to whatever markup protects.

### One emoji, one picture

Which emoji the site has is [`ArchiDep.Emoji`](../emoji.ex)'s to say, and it
says it for the application too: the 📚 of a "more information" note is a
shortcode in a chapter and a component in the dashboard, and both draw the same
Twemoji SVG from `theme/emoji`. The registry is closed — an emoji that is not in
it is not one of the site's — and it is the only place either half writes an
emoji character or the markup one is shown as.

[`EmojiImages`](./renderer/emoji_images.ex) is the pass that draws them, and it
is in the [default options](./renderer/render_options.ex) of every build rather
than left to one: it is the other half of [identifying a heading by what it
says](#a-heading-is-identified-by-what-it-says-not-by-its-decoration), and a
build that ran one without the other would publish anchors named after a
decoration the page then shows as text.

It draws a [deck](#slides-are-not-converted) too, through the same function with
the protected regions of Markdown added, so that a shortcode in a shell
transcript stays a shell transcript. The heading argument does not apply there —
a deck has no identifiers we assign — but the closed vocabulary does: a deck is
the last place that would publish `:coffee:` as words.

It reads a page in either of the two ways one is written — the shortcode
`:books:`, or the character itself — and leaves four things alone:

- **Code**, since the course teaches the command line: `jde:x:1004:` is a line
  of `/etc/passwd`, not an emoji, and the content is full of `:00:` timestamps
  and `:--:` alignment rows.
- **A shortcode naming no emoji of the site**, which is what keeps those
  accidents intact wherever they are written outside code.
- **The markup of the page**, which is scanned past rather than into: an emoji
  is written in a page's words.
- **A character that is not one of the site's emoji** — left as it stands, but
  reported, since it is the one thing on the page that would look different in
  every browser.

An emoji file is a global asset like a stylesheet, so where it is drawn from
goes through [the URL seam](#url-and-link-emission) with the rest.

### A link that leaves the site opens elsewhere

A chapter sends the reader to a manual page or a specification every few
paragraphs, and a link that navigated the tab away would lose the page they are
working through. [`ExternalLinks`](./renderer/external_links.ex) gives every
anchor pointing at another site a `target="_blank"` and the `rel="noopener
noreferrer"` that stops the page it opens from reaching back into the one that
opened it. It is a pass over the finished page rather than over the document
because 184 links of the course are written inside the body of a block tag, and
it is a [default](./renderer/render_options.ex) for the same reason drawing
emoji is: it is the same page wherever it is read.

**Whether a URL leaves the site is `Urls.external?/2`'s to say**, never the
pass's. The build printed to PDF writes the site's own links as
`https://archidep.ch/…`, which nothing but the seam that wrote them can tell
apart from a link to somewhere else — and a build that bakes in no absolute base
URL has no absolute URL of its own at all, so an absolute link in it points away
by construction. That holds because a link to another page of the course is a
[reference](#url-and-link-emission) rather than a URL an author wrote.

An anchor the content wrote by hand that already carries a `target` or a `rel`
is left exactly as it stands: it has already answered the question the pass
asks.

### What a page says about itself

A page introduces itself to things that are not reading it — a browser tab, a
search engine, a chat client unfurling a pasted link — and
[`PageMetadata`](./renderer/page_metadata.ex) is where the three things it says
are decided, instead of in whatever lays the page out. Deciding them in the
layout is how the site came to serve two `<title>` elements per page, its own
and `jekyll-seo-tag`'s, saying different things.

- **What it is called** is the page's title with the site's name after it, which
  is what the application's own layout does.
- **What it is about** is the page's [opening](#the-opening-of-a-page) with its
  markup taken back off, since nothing in the course declares a description. A
  description written anywhere else is one more thing to keep in step with a
  page that changes.
- **Where it really lives** is the page on the **main site**, which is how the
  backup copy and the archived editions avoid competing with it in a search
  engine. A build that does not know where the main site is says nothing rather
  than guessing.

It is a value whatever lays the page out writes into its `<head>`, rather than a
piece of the page: a [`Page`](./renderer/page.ex) is what the site shows _of_ a
page, and the head is around it.

### A heading is identified by what it says, not by its decoration

A heading's identifier is slugged from its text as it is rendered, so `##
:exclamation: Create your server` would be identified by
`exclamation-create-your-server` — a shortcode named in the anchor the course,
the application and every reader's bookmark link to.
[`HeadingIdentifiers`](./renderer/heading_identifiers.ex) moves the shortcode
out of the heading's text and into an inline HTML node, which the renderer
writes out as it stands and the slugger does not read, leaving
`create-your-server` to be linked to and the heading still showing its emoji.

That rewrite is not one of the seams above: like [colouring a code
block](#colouring-a-code-block), it is not a choice a build makes. A build that
skipped it would publish a page whose anchors nothing points at.

### The navigation of a page

[`Toc`](./renderer/toc.ex) reads the "On this page" navigation off the page's
own HTML rather than building it from the document, because both halves of an
entry are only settled there: the identifiers are assigned while the document is
rendered — and numbered (`troubleshooting`, `troubleshooting-1`) according to
what came before them — and a label is the heading as the page shows it, its
shortcodes turned into images by the passes over the finished page. Working
either out again would mean writing a second slugger and keeping the two in
agreement forever.

The entries cover the page, its opening included, and nothing else. The headings
the site shows around a page — the legend of an exercise, the presentation of a
chapter with slides — belong to whatever lays the page out, and so do their
entries.

### Colouring a code block

Highlighting is not one of those seams. Every code block of every document
becomes the `<pre class="lumis">` that
[`Highlighter`](./renderer/highlighter.ex) builds for it, on the way out of
`Renderer.Markdown` and whatever the build asked for, because the theme's two
highlighting stylesheets have one markup to style. What follows the language on
the opening fence is [MDEx's code block decorator
syntax](https://mdex.hexdocs.pm/code_block_decorators.html), of which
`highlight_lines` is supported and anything else is reported.

[Lumis](https://hexdocs.pm/lumis) is called directly rather than through MDEx's
own syntax highlighting, which highlights a block and then splits the HTML it
gets back on newlines to wrap each line in a `<div class="l-line">`: that severs
every token spanning more than one line, which a quarter of the course's fenced
blocks have — a blank line in a shell transcript is enough. Calling Lumis here
is also what marks a line with the `l-highlighted` class the stylesheets define,
rather than the `highlighted` class MDEx asks for and nothing styles.

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

Staying Markdown does not mean staying unresolved. What a deck refers to is
settled here, since nothing downstream will: three things happen to it after the
Liquid stage, in this order.

1. **Its link reference definitions are substituted in**, as above — before
   anything looks at what it refers to, so that a reference link pointing at a
   file is a reference by then.
2. **The files it shows are resolved** to the names they are published under,
   with [`AssetReferences`](./renderer/asset_references.ex). A deck writes them
   both ways, `![](images/x.png)` and `<img src='../images/x.png'>`, and the raw
   HTML is the reason this is a scan of text and not a walk of a document.
3. **Its emoji are drawn**, with the same pass that draws a page's.

Files before emoji: drawing an emoji writes an image of its own, and that image
is an asset of the build rather than a file next to the deck. Doing it in this
order means neither sweep ever sees what the other wrote.

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
These differences are known and expected rather than regressions:

- A heading carries an anchor element (`<h2 id="…">Text<a class="anchor"></a>`)
  that kramdown does not emit.
- **A heading decorated with an emoji shortcode is identified without it**, so
  the 359 headings of the course that open with one — `#create-your-server`
  rather than `#exclamation-create-your-server` — have moved. The shortcode was
  never meant to be part of the anchor; every heading written without one is
  identified exactly as kramdown identified it, verified against every heading
  of every course document.
- **An entry of the table of contents keeps the heading's markup.**
  `jekyll-toc` replaced every element of a heading but an image by its text, so
  a heading naming a command lost its `<code>` in the navigation.
- **A code block is coloured by [Lumis](https://hexdocs.pm/lumis) rather than by
  Rouge**, so it is a `<pre class="lumis">` of `l-*` token classes where Jekyll
  produced `<div class="highlighter-rouge">` of Pygments-style ones, and inline
  code carries no class at all. The theme's two highlighting stylesheets are
  written against the new markup.
- **A column of a `cols` row carries the classes its marker asks for.** Jekyll
  emitted them as the _content_ of the class attribute (`class="&lt;!-- col
md:col-span-2 --&gt;"`), so no column of the course has ever spanned more than
  one. The classes the content writes are already in the stylesheet, since
  Tailwind scans the Markdown they are written in.
- **A folded callout of a cheatsheet is named after the cheatsheet.** Jekyll
  built the prefix from two page variables its generator only sets for a
  chapter, so every one of them was named `-`.
- **A folded callout's congratulation is the same on every build**, where Jekyll
  drew one at random each time it rendered the page.
- **An emoji is a file of the site's own** rather than an image hotlinked from
  `github.githubassets.com`, and every emoji is one: `jemoji` drew the
  shortcodes and left the characters a page or a layout typed to whatever font
  the reader happened to have.
- **A deck's emoji are drawn too.** `jemoji` ran over a rendered page, and a
  deck is handed to the browser as the text of a `<textarea>`, so a deck's
  `:coffee:` was published as five words and its 🛠️ as whatever the reader had.
- **A file next to a page is referred to by its digested name**, where Jekyll
  emitted the plain relative path. The path shape the author wrote is kept, so
  only the file name differs — and `relative_file_url`, which Jekyll's version
  silently returned unchanged, now resolves.
- **A tag's wrapper is emitted without the blank lines Jekyll's has.** kramdown
  tolerated them inside an HTML block; CommonMark ends the block at the first
  one, which would leave the rest of the wrapper to be read as Markdown.
- **A page carries one `<title>`**, where the Jekyll site emits its own and then
  `jekyll-seo-tag`'s, saying the same thing two ways with two different
  separators. Along with the second one go the tags that said nothing true: the
  `generator`, and an `og:type` of `article` whose publication date was the time
  of the build.
- **The site publishes no feed.** `jekyll-feed` wrote a `/feed.xml` of a course
  that has no posts, and nothing has ever linked to it but the `feed_meta` tag
  that announced it.

Everything else matches: the classes, identifiers and structure every tag of
every subject, exercise and cheatsheet emits were diffed against a Jekyll build
of the same content, and the differences above are the whole list.

## Testing

Everything here is pure but [`Build`](./build.ex), so tests are plain
`ExUnit.Case, async: true` with doctests for the self-evident functions,
following the [testing guide][testing]. `Build`'s own tests are `async: true`
too, using ExUnit's `:tmp_dir` tag so each gets a directory of its own; they
assert the manifest a step returns **and** the exact list of files it wrote,
since half of what that module does is the writing. Several specifics for this
subsystem:

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
- Each of the course's own tags has a test file of its own, driving it through
  `Renderer.Liquid.render/1` and asserting the **whole** HTML it emits by `==`.
  That is the tag's contract: it is one string, the theme is written against all
  of it, and a projection of it would be a projection of the thing under test.
  Each file builds its expected wrapper with a helper the test passes the parts
  it is about, so that a test still asserts a whole value.

[app-contributing]: ../../../CONTRIBUTING.md
[bounded-contexts]: ../../../CONTRIBUTING.md#bounded-contexts
[properties]: ../../../docs/testing.md#property-based-tests
[testing]: ../../../docs/testing.md
