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
- [What the course is](#what-the-course-is)
  - [A chapter is the unit](#a-chapter-is-the-unit)
  - [What the course declares about itself](#what-the-course-declares-about-itself)
  - [What it refuses](#what-it-refuses)
  - [The headings a page has](#the-headings-a-page-has)
  - [The compiled model](#the-compiled-model)
- [URL and link emission](#url-and-link-emission)
  - [What a build is](#what-a-build-is)
  - [Reference kinds and their policy](#reference-kinds-and-their-policy)
  - [Assets co-located with a page](#assets-co-located-with-a-page)
  - [Generated PDFs](#generated-pdfs)
  - [Errors](#errors)
- [Building](#building)
  - [Checking it against the real content](#checking-it-against-the-real-content)
- [Laying a page out](#laying-a-page-out)
  - [The chrome](#the-chrome)
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

It is **pure and self-contained**: no `Repo`, no `Endpoint`, no processes, no
request. A build is a function of its inputs, which is what lets the same code
produce the live site, a backup copy hosted elsewhere, a frozen archive of a
past edition, and the build printed to PDF.

It does use `Phoenix.Component`. The site's chrome is markup, and markup is
written in HEEx here as it is in the dashboard — but nothing about that needs an
application to be running: a component is a function of its assigns, and
[`Chrome.Html`](../../../lib/archidep/course_site/layout/chrome/html.ex) turns
one into a string with no conn and no socket. What the rule keeps out is
anything that would need a _running system_ rather than anything named Phoenix.
`~p` is out with it, and out by construction rather than by discipline: `use
Phoenix.Component` does not import `Phoenix.VerifiedRoutes`, so a verified route
does not compile here. Every URL goes through
[`Urls.resolve/2,3`](#url-and-link-emission) instead, which is the rule a stray
`~p` would break loudly rather than quietly.

Every module writing HEEx here also sets `@debug_heex_annotations false` and
`@debug_attributes false`. Those are read at compile time and are on in
development, and what this subsystem writes is a file somebody publishes rather
than a page somebody is debugging in a browser.

Two modules stand outside that, each in one named way, and naming them is what
keeps the claim checkable:

- [`Build`](#building) is the only one that touches the **filesystem**, so a
  stray `File` call anywhere else reads as obviously wrong.
- [`Material`](#the-compiled-model) is the only **edition-bound** value:
  everything else is a function of its inputs, and this is one particular set of
  inputs, worked out while the application compiles. It reads nothing itself —
  it calls `Build` — and it stores the [identities](#identities) defined here
  rather than URLs, so no edition of the course is baked into it either.

## Why this is not a bounded context

`ArchiDep.CourseSite` deliberately sits **outside** the [bounded
contexts][bounded-contexts] and has none of their anatomy — no facade, no use
cases, no schemas, no policy, no events. Those exist to own tables and authorize
access to them; this subsystem owns no state and answers no requests. Keeping it
apart also keeps it honest: it must run standalone, so a stray `Repo` or
`Endpoint` call in here is visibly wrong rather than merely unfortunate.

That covers [`Material`](#the-compiled-model) too, which is the one thing here
the dashboard reads and therefore the one that most looks like a context's read
model. It owns no table, has no use case, policy or event, and every one of its
inputs lives in this namespace. Keeping it here rather than in the [`Course`
context](../course/CONTRIBUTING.md) also closes a hole in the web layer's rule
that every context is replaced by its mock: reached through `Course`, it
bypassed the facade and therefore `Course.ContextMock`.

## Identities

Three modules define how a place in the site is referred to, without naming a
URL:

- [`DocumentRef`](./document_ref.ex) — a course document: a chapter number, a
  slug and a type (`:subject`, `:exercise` or `:slides`). Its
  `parse_source_path/1` is the single place that knows the layout of the content
  directory, including the two ways slides may be written (`slides.md` at the
  chapter root, or `slides/slides.md`), which are one document with one URL.
- [`PageRef`](./page_ref.ex) — anything with a page URL: the home page, a
  document or a cheatsheet. `output_path/1` is where that page lives inside a
  build, with no mount point and no edition prefix.
- [`HeadingRef`](./heading_ref.ex) — a place _inside_ a page: a page and the
  identifier one of its headings carries. Unlike the other two it names
  something no author writes — an identifier is [slugged while the page is
  rendered](#a-heading-is-identified-by-what-it-says-not-by-its-decoration) — so
  one is only ever built from a page that has been read, which is
  [`Headings`](#the-headings-a-page-has)' job.

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

## What the course is

[`Structure`](./structure.ex) is the course as a whole: its sections, the
chapters of each and its cheatsheets, in reading order. It is what
[`Material`](#the-compiled-model) compiles and what the material's own
navigation is drawn from, and it is a function of three inputs — the
[`ContentTree`](./build/content_tree.ex), the front matter of every page of it,
and the [declarations](#what-the-course-declares-about-itself).

It holds the **structure** and nothing else. A chapter's progress — done, due,
next or still to come — changes on every teaching session and is read at build
time from a source of its own, so none of it is in here. That line is what lets
the structure be compiled while the status stays a runtime read.

### A chapter is the unit

The material lists a chapter once, whatever documents it holds, so
[`Chapter`](./structure/chapter.ex) **is** that entry: a page — the chapter's
subject, its exercise, or a deck standing on its own — and, beside it, the deck
that page presents. There is therefore no rule that hides a chapter's deck when
it also has a subject: the deck was never a second entry to be filtered back
out, which is what the Jekyll generator had to do.

Only four fillings of a chapter directory are representable, and they are
exactly the four the [chapter rules](#identities) leave: a subject, a subject
with a deck, an exercise, or a deck alone. `Structure` assumes a tree that
passed those rules rather than re-checking them — it is handed the documents of
a chapter, not the question of whether they may sit together.

A chapter's number is the whole of its position: its section is the first digit
and its place within that section the last two. Those are **functions** of the
number rather than fields of the chapter, and a section's number and slug are
likewise functions of its position and its title, so nothing can be numbered for
one place in the course and listed in another. A cheatsheet's shorter name for a
list falls back to its title the same way.

### What the course declares about itself

Two things no document states: which sections the course has, and in what order
its cheatsheets go. Both are declared in `course/_data/course.yml`, read by
[`Build.declarations/1`](./build.ex) and validated by `Structure.plan/3` — bytes
in the one module that fetches them, rules in the pure one beside it.

The cheatsheet list is **closed**: a cheatsheet the list does not name, or a
name with no cheatsheet behind it, is refused. Jekyll ordered them from a
`_config.yml` key that named three of the four, so the fourth came last by
accident rather than by decision.

### What it refuses

A section is declared while a chapter names one with a digit, and a title is
prose an author can forget, so each of those can be wrong in a way nothing
notices. Every one of them was silent before and is now a build failure listing
every offending document rather than the first: a chapter numbered for a section
nobody declared, a declared section no chapter is numbered for, a page with no
title or with something else in its place, a document graded as neither yes nor
no, a document that is graded and is not an exercise, two sections whose titles
slug alike — which would put two of the navigation's fold checkboxes under one
identifier — and the two halves of the closed cheatsheet list.

The declarations are the one exception to reporting everything: when the list of
sections cannot be read, nothing else about the course can be trusted, so those
are reported alone.

### The headings a page has

A chapter and a cheatsheet are structure; a **heading** is not. `Structure` is a
function of the front matter, and a heading's identifier only exists once the
page has been converted — which is why [`Headings`](./headings.ex) is a thing of
its own rather than a field of `Chapter`. It holds the identifiers of the pages
it was asked about and nothing more, and `heading!/3` is the raising lookup, as
`Structure.chapter!/3` is for a chapter.

It refuses a page and a heading **differently**, because they are different
mistakes. A page it does not hold was never read, which is wrong in the caller.
A heading a page does not have is the course having moved on, so that failure
offers the identifiers closest to the one asked for: what is needed to fix it is
the identifier that replaced the one that is gone.

### The compiled model

[`Material`](./material.ex) is the course as the running application knows it:
`Build.course!/2` called while the module compiles.

It is **compiled** because a page the dashboard names that the course no longer
holds must fail the build rather than a reader's click — which is the whole
point of the module — and because the structure of an edition does not change
while the application runs. What does change is how far it has got, which is why
that is kept apart from it (below). It is compiled from the **Markdown** rather
than from a build artifact so that the application does not need the course
material site to have been built in order to compile at all.

That today's deployed release carries no `course/` directory — the material is
served as static files by then — is a **consequence** of this, not a reason for
it, and it is not permanent: rebuilding the site when progress is toggled from
the database would mean the application holds the content at runtime. What that
fact decides today is narrower, and both places are marked: `Material` resolves
its content directory relative to its own source file rather than through a
configuration knob, so it can only ever mean the repository the application was
compiled from, and the [`Dockerfile`](../../../../Dockerfile) reproduces the
repository layout so that the compile step finds it.

**It stores references, and the application resolves them.** A chapter is a
`Chapter`, whose page is a [`DocumentRef`](#identities), never a URL. The
dashboard turns one into a link through
[`ArchiDepWeb.Helpers.CourseMaterialHelpers`](../../archidep_web/helpers/course_material_helpers.ex),
which is [the seam](#url-and-link-emission) with a `UrlContext` built from the
`:course_site` key of the application's configuration — mount point, edition and
mode, `build_id` a literal, since the application resolves no reference named
after a build. That is what keeps an edition prefix out of a compiled module and
puts it in one place for the whole application.

**A page the dashboard names is an attribute, resolved at compile time.** The
exercise a student is sent to for their virtual server is
`Structure.chapter!(structure, 402, "run-virtual-server")` in `Material` rather
than a lookup at each of the twelve places that link to it, so a renamed chapter
is one compilation failure naming the reference instead of twelve dead links.
The lookup matches on the number **and** the slug — either going stale is a link
that no longer means what it said — but deliberately **not** on the type of the
page: a subject and an exercise are published at the same URL, so a chapter
turned from one into the other is the same chapter at the same address and must
not fail.

**A heading the dashboard names is an attribute too**, and the same argument
applies with more force: a fragment is a string nothing checks, so a reworded
heading used to break ten links silently. `Build.headings!/3` renders the pages
those headings are on while the module compiles, and `Headings.heading!/3` turns
each identifier into a [`HeadingRef`](#identities) or fails the build naming it.
`CourseMaterialHelpers.course_url/1` takes only those values — there is
deliberately no arity taking a fragment as a string, so an unchecked one cannot
be written.

That is the one place a **render** happens while the application compiles, and
it is kept to what it must be: the two pages that are named, with the renderer's
passes dropped. Rendering the whole course, or rendering it with its passes,
would put a build's asset manifests inside `mix compile`. The partials are
needed even so — it is the tags of the course rather than its documents that
include them, a note drawing its icon that way — so `course/_includes` is a
compile-time input alongside the collections, and the
[`Dockerfile`](../../../../Dockerfile) copies it.

**Two mechanisms decide when it is compiled again**, because neither covers the
other's case:

- every Markdown source, the declarations, every recorded session and every
  partial are `@external_resource`s, which is what catches a file being **edited
  or deleted** — Mix compares each one's content digest, so it is immune to a
  fresh checkout;
- `__mix_recompile__?/0` compares `Build.content_digest/1`, a hash of the
  **names** of every file of the collections, which is what catches one being
  **added**. An `@external_resource` cannot: a file nobody registered is a file
  Mix is not watching.

The files beside a page are not registered — their names are all this depends on
and the digest covers those, where registering 49 MB of images would have Mix
digest every one of them on each compile. The digest covers the collections a
build renders, so a newly added **session** is the one change neither mechanism
notices.

**How far the course has got is not part of the structure, and not compiled at
all.** A [`Session`](./session.ex) is what one teaching session recorded and
[`Progress`](./progress.ex) is the union of all of them; both modules say why
the two are kept apart. [`Build.progress/1`](#building) reads them from a file
the **caller** names, since this subsystem configures nothing — which is the
whole of the seam the source needs in order to become a database later.

**The renderer is told what to show, not how far the course has got.**
`solutions_revealed?/2` names the one threshold — a chapter's answers are shown
once it is done, and a chapter that is merely due has work still to hand in —
and whatever builds a page applies it, handing the renderer the answer as
[`RenderContext`](./renderer/render_context.ex)'s `solutions`. So the renderer
never learns the course calendar, an archive of a finished year is a build that
says `:revealed` rather than one carrying a second flag, and moving the source
of the status changes the caller and nothing here.

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
| [`Site`](./build/site.ex)                         | every file a build writes and what is in each, which `site_inputs/1` chains the reads for      |
| [`NotFound`](./build/not_found.ex)                | what a static host shows for a path the build never wrote                                      |
| [`Structure`](./structure.ex)                     | what the course is, which `course!/2` chains the reads for                                     |
| [`Headings`](./headings.ex)                       | what a page's headings are called, which `headings!/3` chains the reads for                    |

A few things about the shape of it are worth knowing before reading any of them.

**A page is read once.** `sources/2` takes every document and cheatsheet of a
content directory apart with [`Source`](./renderer/source.ex) and keys them by
[`PageRef`](./page_ref.ex), because what a page _is_ comes from its front matter
and what it shows comes from its body: `front_matter/1` projects the first for
[`Structure`](#what-the-course-is) and the renderer takes the whole of it. That
is also what `course!/2` chains, rather than a second front-matter-only reader
that would have to be kept in agreement with `Source.parse/1` forever.
`declarations/1` and `progress/1` are the reads that are not files of the site —
see [what the course declares about
itself](#what-the-course-declares-about-itself) and [what the course
is](#what-the-course-is). Both read one file and hand what they decoded to a
pure module that says what it means, which is also how `asset_manifest/1` reads
the digester's manifest. `include_files/1` and `includes/1` are the read of the
partials, which are files of neither: they are what a document is written
against rather than something the site publishes.

**Naming a heading takes a render.** `headings!/3` is the only read that runs
the renderer, because an identifier is [settled while a page is
converted](#a-heading-is-identified-by-what-it-says-not-by-its-decoration). It
renders the pages it is asked about and no others, and
[`Renderer.headings/1`](#the-navigation-of-a-page) drops the passes so that
naming a heading needs no asset manifest — which is what makes it affordable
inside a compilation of [`Material`](#the-compiled-model).

**Listing the files and reading them are separate.** `content_files/1` is the
walk of the content directory, `content_tree/1` is that walk planned, and
`content_digest/1` hashes the same list — so what a build reads and what
[`Material`](#the-compiled-model) watches for a change agree by construction
rather than by two walks happening to match.

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

**A build owns its output directory.** It refuses one that is not empty rather
than merging into it. That is not tidiness: the link check is measured against
what the directory holds, so a page left behind by an earlier build would make a
link that leads nowhere look like a link that resolves. An output that is a
function of its inputs has to start from nothing — which is also the shape the
publish path wants, since rendering into a fresh directory is half of swapping
one into place.

**A render error fails the build.** The renderer is all-or-nothing: any error it
collects discards the page, so there is no such thing as publishing a page that
is known to be wrong. `mix archidep.course_site.assets` sorts errors into those
about a reference and everything else, but that is a property of a check that
answers for the manifests and nothing else — it is not a model for a build.

### Checking it against the real content

Two commands read the real content so that what would otherwise be noticed once
is something anyone can run. Neither writes anything.

- `mix archidep.course_site.assets` builds both manifests from the real content
  and the real assets and renders every document against them, so that a
  reference no longer resolving is a command rather than a broken image.
- `mix archidep.course_site.structure` works out [what the course
  is](#what-the-course-is) from the real content and the real declarations and
  prints it, so that a chapter in an undeclared section, a page with no title or
  a cheatsheet nobody listed is a command rather than a blank entry.

`mix archidep.course_site.build` is the third and the only one that writes: it
renders the whole site into a directory of its own and checks the links of what
it wrote. Every knob of [what a build is](#what-a-build-is) is an option of it,
so the backup copy, an archived edition and the build printed to PDF are
configurations of one command rather than three.

## Laying a page out

[`Layout`](./layout.ex) is what the site shows around a rendered document. The
renderer produces a page's own prose and stops there, so a `<head>`, a header,
the course's navigation and a footer are somebody else's to add, and that
somebody is a value the build is handed rather than a function of it.

It is **one callback** taking a [`LayoutContext`](./layout/layout_context.ex),
not one per kind of page. Choosing between a subject that presents its deck, an
exercise that prints its legend, a bare cheatsheet and a deck that is not a page
at all is the layout's own business: a build that chose would have to learn that
table, and every layout added to it would change the build's shape.

A layout **reports rather than raises**, for the reason [a document
does](#reporting-rather-than-raising): the references it resolves of its own —
its stylesheets, a page's PDF — can fail to resolve, and which of those is fatal
is the layout's to know. A missing stylesheet is a build nobody can read; a PDF
that has not been exported yet is a download link left out.

Two layouts fit the seam. [`Minimal`](./layout/minimal.ex) is the least a
document can be wrapped in and still be shown, for a build whose chrome is not
what is being looked at; [`Chrome`](./layout/chrome.ex) is the site's own, and
what every real build uses.

### The chrome

`Chrome` is one module per thing the Jekyll site kept in a template, under
[`layout/chrome/`](./layout/chrome): the [document](./layout/chrome/document.ex)
and the [deck](./layout/chrome/deck.ex) it dispatches between, the
[header](./layout/chrome/header.ex), [sidebar](./layout/chrome/sidebar.ex) and
[footer](./layout/chrome/footer.ex) around every page, the
[article](./layout/chrome/article.ex) holding one, and the blocks it opens with
— a chapter's [presentation](./layout/chrome/presentation.ex), an exercise's
[legend](./layout/chrome/legend.ex), the home page's title, greeting and
[cards](./layout/chrome/home.ex). What one chapter is called and the picture
beside it is [a module of its own](./layout/chrome/entry_title.ex): the
navigation and the cards both draw it, and a chapter is named the same way
wherever the site lists it.

**Everything is resolved before anything is drawn.**
[`Chrome.Assigns`](./layout/chrome/assigns.ex) is where that happens, and it is
what makes the reporting above possible at all: HEEx evaluates what is
interpolated into it as it goes, so a template resolving its own references
could only raise on the first failure or swallow it, and neither is reporting.
Resolving first means the templates deal in strings and cannot fail — so a page
missing from the output is always a page the build refused, never one something
threw half way through.

Reading `Urls`, only two references the chrome writes can fail: a global asset
that is not in the manifest and a page whose PDF has not been published. So the
fatal/omit split is exactly two combinators, `required` and `optional`, and
which one a reference goes through _is_ the decision the layout is making.

The same module owns the two things the chrome knows that no document does: the
identifiers of the headings it draws (a page's navigation and the heading it
points at are drawn in different places and have to agree), and the entries
those headings add to the front of a page's own.

**What a build carries of the running application** is
[`Chrome.Policy`](./layout/chrome/policy.ex): one value, named field by field,
derived from `UrlContext` `mode` and never from the host. A past edition has no
dashboard whichever host serves it, and the backup copy exists for when the
application is unreachable.

**Icons come from `Heroicons`**, the package the dashboard already draws from,
rather than being copied here — a third copy of the same paths is the
duplication this rendering exists to remove.
[`Chrome.Icons`](./layout/chrome/icons.ex) holds the one icon that package does
not have. The icons a _document_ asks for are a different thing entirely: they
are part of what the page says, and go through the partials it includes.

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
- [`solution`](./renderer/liquid/solution_tag.ex) (a collapsed answer, and the
  one tag whose output depends on which page it is on: an answer is left out of
  the page entirely until the course has covered the chapter, and refused
  outright anywhere but a chapter, since only a chapter has an exercise for it
  to answer)
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

`Renderer.headings/1` is the same reading for a caller that wants to link _into_
a page rather than draw its navigation, and it hands back the identifiers alone.
It renders with the passes dropped, which is safe for exactly the reason the
labels are not: a pass rewrites what a page **shows** — the URL of a file, the
picture of an emoji, the tab a link opens in — and an identifier is slugged
before the first of them runs. That is what lets
[`Build.headings!/3`](#building) answer for a page without either asset
manifest, and the property that the two agree is pinned as a test.

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
- **The 404 page carries none of the site's chrome and loads nothing**, where
  the Jekyll one was a page like any other, with the sidebar, the header and the
  theme's stylesheet around it. A host offering a 404 page at all offers exactly
  one of them for every edition it publishes, and it is shown when something was
  not found — see [`NotFound`](./build/not_found.ex).
- **A deck escapes the one sequence that would cut it short.** Its `<textarea>`
  holds RCDATA, so the markup and the entities a deck writes reach `reveal.js`
  exactly as they stand — but `</textarea` would end the element wherever it
  appeared, so that alone is written as `&lt;/textarea`, which decodes back to
  itself. Jekyll escaped nothing and would have published a broken page for it.

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
- [`Material`](./material.ex) compiles from the real course, so its test asserts
  facts about the **module** rather than about the syllabus: that `sections/0`
  and `cheatsheets/0` are the corresponding fields of `structure/0`, that each
  named reference is the whole `%Chapter{}` or `%HeadingRef{}` it should be, and
  that `__mix_recompile__?/0` answers no — a real oracle, since it fails if the
  digest is not deterministic or reads the wrong directory. The named headings
  are asserted **together**, as one map by `==`, since ten separate assertions
  of one fact each would let a heading be dropped without a test noticing. The
  whole `%Structure{}` of the real course is deliberately **not** asserted: a
  fifty-chapter literal would break on every syllabus edit made by someone who
  is not touching Elixir. What the real content must satisfy is refused by
  `Structure.plan/3` and checked by `mix archidep.course_site.structure`.
- [`Structure`](./structure.ex) is tested by building a course out of
  `ContentTree.plan/1` and a front-matter map written at the call site, and
  asserting the whole `%Structure{}` by `==` — a section's chapters are what the
  test is about, so a projection of them would be a projection of the thing under
  test. Its properties are over `CourseSiteFactory.course_generator/0`, which
  generates a course all three inputs agree on: that every document of the tree is
  part of exactly one chapter, which is the listed-once rule stated as a rule, and
  that a chapter is found by its number and listed under the section that number
  names.
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
- The **chrome** is tested the same way, and for a stronger version of the same
  reason. The [DOM projection rules][dom] do not apply to it: a projection is
  right where "the markup is incidental", and here the markup **is** the value
  and we own all of it — `theme/src/toc.css` selects `.toc-h3 > a`, `course.css`
  selects `#course-material-menu .course-item-due`, `theme.css` safelists
  `peer-has-checked/section-{0..10}`, and Tailwind emits nothing for a class it
  does not scan. A projection that ignored utility classes would ignore
  precisely what can break. So each part asserts the whole fragment it draws by
  `==`, built by a helper from the parts that vary between that file's tests.
- What [`Chrome`](./layout/chrome.ex) itself is tested for is only what it
  decides over and above its parts: which of the two documents a page becomes,
  and that a reference that does not resolve is reported rather than drawn
  around. Everything the chrome works out before drawing is pinned as **values**
  in [`Chrome.Assigns`](./layout/chrome/assigns.ex)'s own tests, which is where
  the error list, the flattened navigation and the layout's own headings are
  asserted.

[app-contributing]: ../../../CONTRIBUTING.md
[dom]: ../../../docs/testing.md#asserting-the-dom-a-meaningful-projection-not-exact-markup
[bounded-contexts]: ../../../CONTRIBUTING.md#bounded-contexts
[properties]: ../../../docs/testing.md#property-based-tests
[testing]: ../../../docs/testing.md
