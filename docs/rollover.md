# Year-end rollover

The course is taught once a year and this repository holds one edition of the
material at a time. The **rollover** is what happens between two of them: the
edition that has ended is rendered one last time and published as frozen bytes,
and the repository starts naming the next one.

It is performed once a year, by hand, in the order below. Everything it needs
already exists as a command or a workflow; what this document adds is the order,
and the handful of things that are easy to get wrong and expensive to correct.

Why an edition is frozen rather than kept rebuildable, and where the bytes live,
is documented with the subsystem that renders it — see [The editions that came
before][editions] and [`ArchiDep.CourseSite.Urls.UrlContext`][url-context] for
what the three build modes mean.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [What it produces](#what-it-produces)
- [The procedure](#the-procedure)
  - [0. Rehearse the freeze](#0-rehearse-the-freeze)
  - [1. Record what the edition published](#1-record-what-the-edition-published)
  - [2. Verify and tag the source](#2-verify-and-tag-the-source)
  - [3. Move the edition knob](#3-move-the-edition-knob)
  - [4. Publish the frozen edition](#4-publish-the-frozen-edition)
  - [5. Deploy, and read the completeness check](#5-deploy-and-read-the-completeness-check)
- [Correcting a frozen edition](#correcting-a-frozen-edition)
  - [Before it has been published](#before-it-has-been-published)
  - [After it has been published](#after-it-has-been-published)
  - [The manifest is not part of the frozen bytes](#the-manifest-is-not-part-of-the-frozen-bytes)
  - [The PDFs](#the-pdfs)
- [What the new edition owes](#what-the-new-edition-owes)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

---

## What it produces

Take the 2025 edition ending and 2026 beginning. When the rollover is done:

- `archidep.github.io` holds `2025/` as an **`:archive`** build — every page
  carrying the banner that offers the current version of itself, and asking
  crawlers to leave it alone — where it previously held that year's backup copy.
- The source it was rendered from is tagged `archive/2025`, and
  `2025/version.json` inside the published tree names the same commit.
- This repository configures `2026`, so every build lands beside the frozen
  editions rather than over them, and `course/archives/2025.json` is the record
  of what 2025 published, which the `/latest` resolver answers from.
- Both hosts serve both editions: `archidep.ch` from its own image plus the
  clone of the archive repository, `backup.archidep.ch` from the repository
  itself.

**The new edition renders the old material at first.** Moving the knob is not
the same act as upgrading the content, and nothing forces them to happen
together: until the material is reworked, `/2026/` publishes what `/2025/` said.
That is expected, and it is why the rollover comes first — see [What the new
edition owes](#what-the-new-edition-owes).

---

## The procedure

### 0. Rehearse the freeze

```bash
# Actions → rollover → Run workflow
#   year: 2025
#   ref:  (blank)
#   mode: check
```

The [`rollover` workflow][rollover-workflow] renders the edition, asserts
everything that can be asserted about what came out, and prints what publishing
would change — and in `check` mode writes nothing anywhere. It is dispatched
once a year and will have rotted in between, so **this is the first step, not a
precaution**: fix whatever it reports before going any further.

At this point it will warn that `main` still teaches 2025, which is correct and
is the reason this step can be run before the rest.

The rehearsal needs the previous year's tag to exist. The first time — the 2025
rollover — there is nothing to rehearse against, so run `check` after step 2
instead, before publishing.

### 1. Record what the edition published

```bash
cd app && mix archidep.course_site.archives
```

Writes `course/archives/<year>.json`: every page the ending edition published,
with the identity that edition gave it. Re-running it on unchanged content
rewrites an identical file, so a clean `git status` means the record was already
correct.

Do this **before** the tag: the manifest is committed here, and this is the last
moment anything knows those identities — see [The editions that came
before][editions].

### 2. Verify and tag the source

Everything the repository checks, since these bytes are permanent:

```bash
cd app && mix format --check-formatted && mix credo --strict && mix test && mix dialyzer
npm run lint:md && npm run format
```

Then tag the commit that will be frozen — the **last one whose
`app/config/config.exs` still names the ending edition**, which is the commit
before step 3:

```bash
git tag -a archive/2025 -m 'The 2025-2026 edition as it was taught'
git push origin archive/2025
```

### 3. Move the edition knob

Four values in [`app/config/config.exs`](../app/config/config.exs) move
together, and the file explains why the first two do:

| Knob          | 2025                           | 2026                           |
| ------------- | ------------------------------ | ------------------------------ |
| `version`     | `"2025"`                       | `"2026"`                       |
| `years`       | `"2025-2026"`                  | `"2026-2027"`                  |
| `years_short` | `"25-26"`                      | `"26-27"`                      |
| `pdf_base`    | `…/releases/download/pdf/2025` | `…/releases/download/pdf/2026` |

Commit and push to `main`. Two workflows react:

- [`build.yml`][build-workflow] publishes the new edition's backup copy into the
  archive repository, and the root files with it, and **stops touching the
  previous year's directory** — which is what makes step 4 safe to run at
  leisure.
- [`pdf.yml`][pdf-workflow] prints the new edition's PDFs and creates the
  `pdf/2026` release. Download links 404 until it finishes.

### 4. Publish the frozen edition

```bash
# Actions → rollover → Run workflow
#   year: 2025
#   ref:  (blank)
#   mode: publish
```

Same run as the rehearsal, plus the push. It refuses to publish while `main`
still teaches the year being frozen, so step 3 cannot be skipped or reordered by
accident.

The published directory is replaced whole, so what is served afterwards is
exactly what was rendered.

### 5. Deploy, and read the completeness check

Deploy the latest version of the application.

This is the step that hands the outgoing edition over: until it runs,
`archidep.ch` serves that year from the image built from it; afterwards, from
the clone, like every other finished edition.

Then read what the application says about whether it holds every edition it
should — at boot, as one error line per problem, and in the admin console. A
deployment that reports nothing holds everything; the check is documented in
[`ArchiDep.CourseSite.Archives.Completeness`][completeness].

---

## Correcting a frozen edition

A mistake found in a published edition is fixed by **freezing it again**, never
by editing what was published. The tree in the archive repository is generated,
and a hand-edited page there would be silently replaced by the next thing that
syncs.

### Before it has been published

A tag that nothing has been published from names nothing yet. Move it:

```bash
git tag -f archive/2025 <commit>
git push --force origin archive/2025
```

A tag becomes immutable the moment a build made from it has been pushed to the
archive repository.

### After it has been published

The fix is a new commit, a new tag and a new run — the original tag stays where
it is:

```bash
git switch --create fix/archive-2025 archive/2025
# fix, then verify with the commands in step 2
git commit
git tag -a archive/2025.2 -m 'The 2025-2026 edition, corrected'
git push origin archive/2025.2
```

```bash
# Actions → rollover → Run workflow
#   year: 2025
#   ref:  archive/2025.2
#   mode: check, then publish
```

Three things about this are deliberate:

- **The tag is added, never moved.** Which freeze is live is never inferred from
  a tag anyway: `2025/version.json` names the commit serving today, and `git log
-- 2025/` in the archive repository is the history of every freeze and what
  superseded it.
- **The branch is not merged.** Delete it once it is tagged; the tag holds the
  commit. If the same bug affects the edition being taught, fix it on `main`
  separately — one bug, two deliberate acts, because the second one re-renders a
  finished year.
- **Publishing replaces the directory.** The correction is complete rather than
  additive, so a page dropped by the fix stops being served.

### The manifest is not part of the frozen bytes

`course/archives/<year>.json` lives on `main` and is read by the **running**
application to resolve `/latest`, so correcting it needs no re-freeze — but it
cannot simply be regenerated either, once the content has moved on: the task
reads the course as it is now, and would record the current edition's pages
under the old year. Run it against the frozen tree instead, and commit the
result on `main`:

```bash
git switch --detach archive/2025
cd app && mix archidep.course_site.archives --output /tmp/2025.json
git switch main && cp /tmp/2025.json course/archives/2025.json
```

The rollover workflow reads the copy on `main` when it checks that every page a
manifest promises was rendered, and warns when the two disagree.

### The PDFs

They are release assets tagged `pdf/<year>`, not part of the published tree.
Re-print them by dispatching [`pdf.yml`][pdf-workflow] from the corrected tag
with `force` — it reads the edition from the tree it was dispatched on and
uploads over the existing release.

---

## What the new edition owes

As the material is reworked for the year that has just begun, the pages of the
archived editions have to keep resolving to something. Matching is by kind and
slug, so a renumbered chapter costs nothing and needs no entry; what is owed is
the difference — pages **renamed or dropped** since — declared in
[`course/archives.yml`](../course/archives.yml).

This is not optional bookkeeping: an archived page that matches nothing and is
declared nothing **fails the build**. That is what stops the mapping from
quietly decaying, and it means the entry is owed in the same change as the
rename, not at the next rollover.

[build-workflow]: ../.github/workflows/build.yml
[completeness]: ../app/lib/archidep/course_site/archives/completeness.ex
[editions]: ../app/lib/archidep/course_site/CONTRIBUTING.md#the-editions-that-came-before
[pdf-workflow]: ../.github/workflows/pdf.yml
[rollover-workflow]: ../.github/workflows/rollover.yml
[url-context]: ../app/lib/archidep/course_site/urls/url_context.ex
