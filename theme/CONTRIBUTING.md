# Contributing

Please read this document to understand how the ArchiDep theme is structured and
what guidelines to follow when contributing.

The adjacent [`AGENTS.md`](./AGENTS.md) file contains additional instructions
for AI assistants and automated agents.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Overview](#overview)
  - [Integration With Other Components](#integration-with-other-components)
  - [Build Output](#build-output)
- [Directory Structure](#directory-structure)
- [General Coding Guidelines](#general-coding-guidelines)
- [Theme Implementation](#theme-implementation)
  - [Entry Points](#entry-points)
  - [Tailwind Configuration](#tailwind-configuration)
  - [Themes & Dark Mode](#themes--dark-mode)
  - [Typography & Fonts](#typography--fonts)
  - [Syntax Highlighting](#syntax-highlighting)
  - [Course & Application Components](#course--application-components)
- [Build & Development](#build--development)
- [Formatting & Linting](#formatting--linting)
- [Useful Commands](#useful-commands)
- [References](#references)
- [For AI Agents](#for-ai-agents)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

---

## Overview

The `theme` directory provides the shared [Tailwind CSS][tailwind] theme used by
both main components of the ArchiDep website:

- the dashboard application implemented with Phoenix (see [`CONTRIBUTING.md` in
  the `app` directory][app-contributing]), and
- the course material site, rendered by that application from the sources in the
  `course` directory (see [`CONTRIBUTING.md`][course-contributing] there).

It is built with [Tailwind CSS][tailwind] v4 and integrates the
[DaisyUI][daisyui] component library and the [Tailwind
Typography][tailwind-typography] plugin. Rather than a JavaScript configuration
file, Tailwind v4 is configured directly in CSS (see [Tailwind
Configuration](#tailwind-configuration)).

The theme defines the unified visual style for the whole website: the color
themes (including dark mode), the custom fonts, the prose and heading styles, the
syntax highlighting, and the styling of the various custom components used in the
course material (notes, callouts, columns, Git diagrams, etc.) and the
application.

### Integration With Other Components

Because the same theme styles both components, both are scanned by Tailwind to
determine which utility classes to generate (see [Tailwind
Configuration](#tailwind-configuration)). When you add or change Tailwind utility
classes in the application's templates (`app/lib/archidep_web`) or in the course
material (`course/`), the theme must be rebuilt for the new classes to appear in
the compiled CSS. During development, run the theme in watch mode so this happens
automatically (see [Build & Development](#build--development)).

The overall UI (header & sidebar) is shared between the application and the
course material site to provide a seamless experience when switching between the
two, which is only possible because both rely on this single theme.

### Build Output

The theme compiles into the application's static assets directory, from which
the running application serves it:

- `src/theme.css` is compiled to `app/priv/static/assets/theme/theme.css`.
- `src/slides.css` is compiled to `app/priv/static/assets/theme/slides.css`.
- `emoji/*.svg` are copied to `app/priv/static/assets/emoji/`.
- The font files the stylesheets name are copied to
  `app/priv/static/assets/fonts/`. See [Typography & Fonts](#typography--fonts).

All output files are generated and ignored by Git. The application must have the
theme built for it to compile and serve pages correctly, as documented in the
[`app` directory][app-contributing] and in the main [README.md](../README.md).

---

## Directory Structure

- **Stylesheets**
  - `src/theme.css`: Main entry point compiled into the website's stylesheet. It
    imports Tailwind, the plugins, the configuration and all the other
    stylesheets below (except `slides.css`). See [Entry Points](#entry-points).
  - `src/slides.css`: Separate entry point for the [reveal.js][reveal] slide
    decks, compiled into its own stylesheet. See [Entry Points](#entry-points).
  - `src/shared.css`: Base heading, prose and emoji styles shared across the
    whole website.
  - `src/app.css`: Styles specific to the dashboard application.
  - `src/course.css`: Styles specific to the course material (notes, callouts,
    columns, legends, blockquotes, emoji-prefixed headings, progress menu,
    etc.). The largest stylesheet.
  - `src/cheatsheet.css`: Heading sizes specific to cheatsheets.
  - `src/search.css`: Styles for the full-text search dialog and results.
  - `src/toc.css`: Styles for the table of contents shown in the sidebar.
  - `src/git-memoir.css`: Styles for the interactive [Git memoir][git-memoir]
    diagrams. Imported by both `theme.css` (via `course.css`) and `slides.css`.
  - `src/fonts.css`: The `@font-face` rules for the three families the site is
    set in, imported by both entry points. See [Typography &
    Fonts](#typography--fonts).
  - `src/highlight-light.css` & `src/highlight-dark.css`: Syntax highlighting
    color schemes for code blocks. See [Syntax Highlighting](#syntax-highlighting).
- **Other Files**
  - `emoji/`: The site's emoji as [Twemoji][twemoji] SVG files, copied into the
    static assets by the build. Both the course material and the application
    draw their emoji from these files so that the same emoji is the same picture
    everywhere; which ones exist is decided in [`ArchiDep.Emoji`][emoji], and
    [`emoji/README.md`](./emoji/README.md) says where they come from and how to
    add one.
  - `scripts/copy-emoji.mjs`: Copies the above into the static assets.
  - `scripts/copy-fonts.mjs`: Copies the font files `src/fonts.css` names into
    the static assets.
  - `package.json`: npm workspace configuration, dependencies and build scripts.
  - `.gitignore`: Ignores the local `dist` directory.

---

## General Coding Guidelines

- **Main Frameworks, Languages and Libraries**
  - [Tailwind CSS][tailwind] v4 for utility-first styling, configured in CSS
  - [DaisyUI][daisyui] for semantic component classes (`btn`, `join`,
    `skeleton`, etc.) and the color themes
  - [Tailwind Typography][tailwind-typography] for the `prose` classes applied to
    rendered Markdown content
- **Styling Guidelines**
  - Prefer Tailwind utility classes. Use the `@apply` directive to attach
    utilities to semantic selectors when styling markup generated by the course
    site renderer, Lumis or third-party libraries that you cannot annotate with
    classes directly.
  - Prefer DaisyUI semantic color names (`primary`, `base-content`, `accent`,
    `success`, `info`, `warning`, `error`, etc.) over hardcoded colors so that
    styles adapt automatically to the active theme and to dark mode.
  - Support dark mode for any new style using the `dark:` variant (or
    theme-aware DaisyUI colors). See [Themes & Dark Mode](#themes--dark-mode).
  - Consider print output: use the `print:` and `screen:` variants where
    appropriate, since course material is meant to be printable and exportable to
    PDF.
  - Place new styles in the stylesheet matching their scope (see [Directory
    Structure](#directory-structure)) rather than growing `theme.css` directly.
  - Consider accessibility and responsiveness in all changes, using Tailwind's
    responsive variants (`sm:`, `md:`, `lg:`, `xl:`, `2xl:` and the custom `xs:`
    breakpoint).

---

## Theme Implementation

### Entry Points

The theme has two independent entry points, each compiled into its own
stylesheet:

- **`theme.css`** is the main stylesheet for the website (the dashboard
  application and the regular course material pages). It imports Tailwind, the
  plugins, the theme configuration and all the other stylesheets (`shared.css`,
  `search.css`, `app.css`, `course.css`, `cheatsheet.css`, the highlight schemes
  and `toc.css`).
- **`slides.css`** is a separate, smaller stylesheet for the
  [reveal.js][reveal] slide decks. Slides have their own base styling and layout,
  so they are kept isolated from the main stylesheet to avoid conflicts. It
  imports `git-memoir.css` for the Git diagrams that can appear in slides.

### Tailwind Configuration

This theme uses [Tailwind CSS][tailwind] v4, which is configured directly in CSS
rather than in a `tailwind.config.js` file. The configuration lives in the entry
points (`theme.css` and `slides.css`) and uses the following directives:

- `@import 'tailwindcss'` pulls in Tailwind itself. `slides.css` instead imports
  the individual `theme` and `utilities` layers to keep its output minimal.
- `@plugin "daisyui"` and `@plugin "@tailwindcss/typography"` enable the
  [DaisyUI][daisyui] and [Tailwind Typography][tailwind-typography] plugins. The
  DaisyUI plugin block also declares the active themes (see [Themes & Dark
  Mode](#themes--dark-mode)).
- `@theme { ... }` defines design tokens such as the custom `xs` breakpoint
  (`--breakpoint-xs`) and the title font (`--font-title`).
- `@source "..."` tells Tailwind which files to scan for class names. The theme
  scans the application's web templates (`app/lib/archidep_web`), the course
  site's own chrome (`app/lib/archidep/course_site/layout`, which is Elixir
  rather than Liquid), the [Flashy][flashy] dependency used for notifications,
  and the course material (`course/chapters`, `course/cheatsheets`,
  `course/icons`, `course/index.md` and `course/src/assets`, named one by one
  rather than as `course/` so that Tailwind does not scan the directory's
  `node_modules` and build outputs). This is why the theme must be rebuilt
  whenever utility classes change in any of them (see [Integration With Other
  Components](#integration-with-other-components)).

  These paths are build inputs, and Tailwind passes over one that is not there
  without a warning or a failing exit code: the build succeeds and the
  stylesheet is simply missing every class used only by the tree that was
  absent. Whenever you add an `@source`, make sure each environment that builds
  the theme has the files it names — the development containers mount them (see
  the `theme` service in `compose.dev.yml`) and the production image copies them
  into its `theme` stage (see the [`Dockerfile`](../Dockerfile)).

- `@source inline("...")` safelists classes that are composed dynamically and
  therefore cannot be discovered by scanning, such as the `section-{0..10}`
  peer/group classes used by the course progress indicators.
- `@custom-variant` defines extra variants, notably `screen:` (styles that apply
  only on screen, not in print) and, in `slides.css`, a `dark:` variant scoped to
  the slides' `data-theme` attribute.

### Themes & Dark Mode

The main stylesheet enables two [DaisyUI][daisyui] themes in its `@plugin
"daisyui"` block:

- `nord` is the default (light) theme.
- `night` is used automatically when the user's system prefers a dark color
  scheme (`--prefersdark`).

Style dark-mode variations using the `dark:` variant or, preferably, theme-aware
DaisyUI semantic colors, so that the dashboard application and the course
material both honor the same light/dark behavior described in the [`app`][app-contributing]
and [`course`][course-contributing] documentation.

### Typography & Fonts

Three families, declared by `src/fonts.css` — which both entry points import —
and applied in `shared.css`:

- **Bitcount Prop Single** — the title font, exposed as the `--font-title` theme
  token and used for `h1` headings and slide titles.
- **Fjalla One** — used for `h2`–`h6` headings.
- **PT Sans** — the default body font (`--default-font-family`).

**They are served from where the site is served**, never fetched from a font
host: a page has to look the same offline, in a container that cannot resolve a
name, and in the headless browser that prints the PDFs — which would otherwise
print every title in a fallback font and say nothing. `src/fonts.css` is
therefore the `@font-face` rules themselves, and `scripts/copy-fonts.mjs`
publishes the files they name, working out which those are by reading them: a
face named in the stylesheet that no installed package provides stops the build
rather than 404ing in a browser. Adding a family means installing its
[Fontsource][fontsource] package, listing it in that script and declaring its
faces — the static package rather than the `-variable` one, and one face per
weight the family is used at, for the reason `src/fonts.css` gives.

The addresses in those rules are **relative to the stylesheet** (`../fonts/…`),
as is everything an asset fetches for itself. A build publishes its assets under
its edition prefix, under a mount point, or at the root of an export, and
nothing bundled can know which; only the URLs the renderer emits go through [its
seam][urls].

### Syntax Highlighting

Code blocks in the course material are highlighted at build time by
[Lumis][lumis], which emits `<pre class="lumis">` with one `<div
class="l-line">` per line and `l-*` token classes (`.l-keyword`, `.l-string`,
`.l-function`, etc.). The theme provides two color schemes for these classes:

- `highlight-light.css` is the default scheme, the Solarized Light palette.
- `highlight-dark.css` is the Solarized Dark palette inside a `@media
(prefers-color-scheme: dark)` query, so highlighting follows the system color
  scheme to match the [DaisyUI dark theme](#themes--dark-mode).

**Both files are generated** — one rule per token class of a color scheme, a few
hundred of them — by the `mix theme.highlight_css` task of the [dashboard
application][app-contributing], which is also where the themes they are built
from are named. Run it from the `app` directory after changing either theme and
after upgrading Lumis; do not edit the two files by hand.

The structural rules the markup needs — a code block bleeding into the page
margins, a marked line spanning a block that scrolls, the spacing of a block
inside a note or a solution — are in `course.css` rather than in the generated
files. A marked line (`.l-highlighted`, which a code fence asks for with the
`highlight_lines` decorator documented in the [course material
documentation][course-code-blocks]) is colored by the scheme itself.

### Course & Application Components

Much of `course.css` styles markup produced by the custom Liquid tags and
features documented in the [course material
documentation][course-contributing]. When changing these styles, refer to that
document for the meaning and intended behavior of each feature:

- **Notes** (`.note`, `.note-tip`, `.note-warning`, etc.) — styled note boxes.
  See [Notes][course-notes].
- **Callouts** (`.callout`, `.callout-exercise`, `.callout-more`, etc.) — the
  more prominent callout boxes, including the collapsible "Tell me more" behavior
  of `more` callouts. See [Callouts][course-callouts] and [Tell Me
  More][course-tell-me-more].
- **Columns** (`.cols`) — responsive side-by-side columns. See
  [Side-by-Side Columns][course-cols].
- **Git memoirs** (`git-memoir`) — the interactive [Git diagrams][git-memoir]
  rendered from `course/src/assets/git-memoir`.
- **Progress indicators** (`#course-material-menu .course-item-*` /
  `.course-section-*`) — the done/due/next/future markers in the sidebar.
- **Search** (`#search-dialog`) — the full-text search dialog shared with the
  application.

The application-specific styles in `app.css` are minimal; most of the
application's appearance comes from DaisyUI components and the shared styles.

---

## Build & Development

The theme is a workspace of the root npm project. The build uses the
[Tailwind CSS CLI][tailwind-cli] to compile and minify the entry points into the
application's static assets directory (see [Build Output](#build-output)).

- For a one-off build, run `npm run --workspace theme build` from the repository
  root (or `npm run build` from within the `theme` directory). This is required
  at least once before the application can be built, as documented in the main
  [README.md](../README.md).
- For development, run the theme in watch mode with `npm start` (from the
  `theme` directory) so that the stylesheets are rebuilt whenever a source
  stylesheet or a scanned template changes. The watch task runs alongside the
  application, as described in the [development instructions](../README.md).
  When using the Docker development environment, this runs automatically in the
  `theme` container.

The `start` and `build` scripts each compile both entry points (`theme.css` and
`slides.css`); the `:main` and `:slides` variants compile only one.

---

## Formatting & Linting

- Use [Prettier][prettier] to format the CSS stylesheets. Formatting for the
  theme is handled by the project-wide Prettier configuration; run `npm run
format` (check) or `npm run format:write` (apply) from the repository root, as
  documented in the root [`CONTRIBUTING.md`](../CONTRIBUTING.md). The theme has
  no component-specific formatting, linting or testing commands.

---

## Useful Commands

Run these from the `theme` directory (or prefix with `npm run --workspace theme`
from the repository root):

- `npm run build`: Publish the emoji and fonts, then build and minify both
  stylesheets.
- `npm run build:emoji`: Copy only the emoji into the static assets.
- `npm run build:fonts`: Copy only the fonts into the static assets.
- `npm run build:main`: Build and minify only `theme.css`.
- `npm run build:slides`: Build and minify only `slides.css`.
- `npm start`: Publish the emoji and fonts, then build both stylesheets and
  watch for changes (without minification).
- `npm run start:main`: Watch and rebuild only `theme.css`.
- `npm run start:slides`: Watch and rebuild only `slides.css`.

---

## References

- [Tailwind CSS][tailwind] for utility-first styling
  - [Tailwind CSS Documentation][tailwind]
  - [Tailwind CSS CLI][tailwind-cli]
  - [Tailwind Typography][tailwind-typography] plugin for `prose` styles
- [DaisyUI][daisyui] for components and themes
  - [DaisyUI Documentation][daisyui]
- [Lumis][lumis] for syntax highlighting
- [Prettier][prettier] for code formatting

---

## For AI Agents

Follow the instructions and guidelines in this document and read the adjacent
[`AGENTS.md`](./AGENTS.md) file for additional instructions targeted towards AI
agents.

[app-contributing]: ../app/CONTRIBUTING.md
[course-contributing]: ../course/CONTRIBUTING.md
[course-notes]: ../course/CONTRIBUTING.md#notes
[course-callouts]: ../course/CONTRIBUTING.md#callouts
[course-tell-me-more]: ../course/CONTRIBUTING.md#tell-me-more
[course-cols]: ../course/CONTRIBUTING.md#side-by-side-columns
[course-code-blocks]: ../course/CONTRIBUTING.md#code-blocks
[daisyui]: https://daisyui.com/docs/
[emoji]: ../app/lib/archidep/emoji.ex
[flashy]: https://hexdocs.pm/flashy/readme.html
[fontsource]: https://fontsource.org
[git-memoir]: https://github.com/AlphaHydrae/git-memoir
[lumis]: https://hexdocs.pm/lumis
[prettier]: https://prettier.io
[reveal]: https://revealjs.com
[tailwind]: https://tailwindcss.com/docs
[tailwind-cli]: https://tailwindcss.com/docs/installation/tailwind-cli
[tailwind-typography]: https://github.com/tailwindlabs/tailwindcss-typography
[twemoji]: https://github.com/jdecked/twemoji
[urls]: ../app/lib/archidep/course_site/CONTRIBUTING.md#url-and-link-emission
