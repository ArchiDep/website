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

A page URL identifies a page **less** precisely than a reference does, because a
chapter's subject and its exercise share one URL. `PageRef.identity/1` is that
weaker identity and `parse_output_path/1` recovers it from a path — enough to
match an archived page against the current edition of the course.

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

The slides' and cheatsheets' PDFs are generated by a separate, human-run step.
[`PdfManifest`](./urls/pdf_manifest.ex) says where they are published: `:site`
(under the build's own prefix) or `{:external, base}` (a bucket, a release —
anywhere the server does not have to store them). An entry may also be a `{:url,
url}` override, for a host that renames what it is given and therefore publishes
at a URL that cannot be derived from the local file name.

A page whose PDF has not been published resolves to `{:error, {:unknown_pdf,
_}}`. Unlike a missing image, that is **not** necessarily a build failure:
during the year a chapter may simply not have been exported yet, and the caller
is expected to leave the download link out.

### Errors

`resolve/3` returns `{:ok, url}` or `{:error, reason}`; `resolve!/3` raises a
[`UrlError`](./urls/url_error.ex). Use the tuple where a failure is a fact about
the content — a renderer turns it into an error naming the offending tag, and
the build collects every broken reference of a document rather than stopping at
the first. Use the bang where a failure is a programmer error, such as the
application's own navigation. Both render their message with `format_error/1`,
so there is one wording for the same problem wherever it surfaces.

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
  build is published, that a global asset is never absolutized, and that the
  identity round-trips hold. Generators live in
  [`CourseSiteFactory`](../../../test/support/course_site_factory.ex).

[app-contributing]: ../../../CONTRIBUTING.md
[bounded-contexts]: ../../../CONTRIBUTING.md#bounded-contexts
[properties]: ../../../docs/testing.md#property-based-tests
[testing]: ../../../docs/testing.md
