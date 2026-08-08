# Contributing

Please read this document to understand how the ArchiDep course material site is
structured and what guidelines to follow when contributing.

The adjacent [`AGENTS.md`](./AGENTS.md) file contains additional instructions
for AI assistants and automated agents.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Overview](#overview)
  - [Integration With Other Components](#integration-with-other-components)
  - [Standalone Mode](#standalone-mode)
- [Site Structure](#site-structure)
- [Course Material](#course-material)
  - [Writing Guidelines](#writing-guidelines)
  - [Document Types](#document-types)
  - [File Naming Conventions](#file-naming-conventions)
  - [Document Front Matter](#document-front-matter)
  - [Progress Tracking](#progress-tracking)
  - [Special Tags and Features](#special-tags-and-features)
    - [Notes](#notes)
    - [Callouts](#callouts)
      - [Tell Me More](#tell-me-more)
    - [Side-by-Side Columns](#side-by-side-columns)
    - [Solutions](#solutions)
    - [Mermaid Diagrams](#mermaid-diagrams)
    - [Forced Markdown](#forced-markdown)
    - [Code Blocks](#code-blocks)
    - [Cloud Server Widget](#cloud-server-widget)
    - [Randomized Values](#randomized-values)
    - [Interactive Git Diagrams](#interactive-git-diagrams)
- [General Coding Guidelines](#general-coding-guidelines)
- [Site Implementation](#site-implementation)
  - [Custom Jekyll Plugins](#custom-jekyll-plugins)
  - [Configuration & Deployment Modes](#configuration--deployment-modes)
  - [Build Output & Asset URLs](#build-output--asset-urls)
  - [JSON Exports](#json-exports)
  - [Client-Side Architecture](#client-side-architecture)
  - [Search](#search)
  - [Slides](#slides)
  - [PDF Generation](#pdf-generation)
  - [Home Page](#home-page)
- [Formatting and Linting](#formatting-and-linting)
- [References](#references)
- [For AI Agents](#for-ai-agents)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

---

## Overview

This site contains the course materials for students of the Media Engineering
Architecture & Deployment course. It is one of the two main parts of the whole
ArchiDep website, the other part being a dashboard application for teachers and
students (see [`CONTRIBUTING.md` in the `app`
directory](../app/CONTRIBUTING.md)).

The content of the course organized into subjects, slides, exercises and
cheatsheets, a list of most of these is displayed in the sidebar. Slides are
either part of a subject, or standalone documents. Some exercises are graded.

The key features are:

- Sidebar navigation for subjects, slides, exercises and cheatsheets
- Progress tracking with visual indicators
- Responsive design for various screen sizes
- Real-time integration with the application dashboard
- Full-text search across all course materials
- Dark mode support for better readability in low-light environments
- Print-friendly styles for physical copies of course materials
- PDF generation for offline access
- JSON exports of course structure and search data for integration with the
  dashboard application

### Integration With Other Components

The overall UI (header & sidebar) is shared between the course material site and
the dashboard application to provide a seamless experience when switching
between the two. The Tailwind CSS theme for the whole website, used in both
components, can be found in the `theme` directory (see [`CONTRIBUTING.md` in the
`theme` directory](../theme/CONTRIBUTING.md)).

### Standalone Mode

The course material site can also be built and served as a standalone site
without the integration with the dashboard application. This is useful for
hosting a backup copy of the course materials, and for archival purposes (since
the dashboard functionality is only available during the current semester).

---

## Site Structure

- **Main Parts**
  - `index.md`: The home page of the course material site.
  - `collections/_course`: The main course materials, including subjects, slides
    and exercises, all identified with a simple numeric code (101, 102, 103,
    201, 202, etc).
  - `_data/course.yml`: The definition of the overall course sections into which
    the materials are organized, and the order the cheatsheets are listed in.
    Both are things no single document states.
  - `collections/_cheatsheets`: Cheatsheets for students to quickly reference
    key concepts and commands.
  - `collections/_json`: JSON data exports for integration with the dashboard
    application.
- **Important Files**
  - `_plugins/archidep.rb`: Custom Jekyll plugin to enrich documents with
    additional metadata, such as determining the type of document (subject,
    slide, exercise, cheatsheet) and extracting the numeric code from filenames,
    building the search data, and various other things. See [Custom Jekyll
    Plugins](#custom-jekyll-plugins).
  - `_plugins/utils.rb`: Shared Ruby helpers used by the custom tags and
    plugins, such as Markdown rendering, SVG icon rendering and Markdown
    reference-link resolution.
  - `_plugins/filters.rb`: Custom Liquid filters (e.g. `collapse_whitespace`).
  - `_plugins/relative_asset_url.rb`: Custom Liquid filters that resolve
    cache-busted asset URLs from the Webpack and Phoenix manifests. See [Build
    Output & Asset URLs](#build-output--asset-urls).
  - `_plugins/tags/**/*.rb`: Custom Liquid tags to spruce up course content,
    such as callout boxes, styled notes, responsive side-by-side columns,
    collapsible solutions and Mermaid diagrams. See [Special Tags and
    Features](#special-tags-and-features).
  - `src/assets/course.ts` & `src/assets/course/**/*.{ts,tsx,html}`: TypeScript
    and HTML files for client-side interactivity, such as the search dialog,
    copy-to-clipboard buttons, the cloud server widget, randomized exercise
    values, analytics and real-time integration with the dashboard. See
    [Client-Side Architecture](#client-side-architecture).
  - `src/assets/utils.ts` & `src/assets/errors.ts`: Small shared helpers and
    error types used across the client-side modules.
  - `src/assets/git-memoir/**/*.ts`: TypeScript definitions of interactive Git
    diagrams shown in some slides and exercises, and a renderer to display them.
  - `src/assets/slides.ts` & `src/assets/slides/**/*.ts`: TypeScript files to
    enhance slide presentations with features like Git diagrams.
  - `src/assets/slides-mermaid.ts`: TypeScript file to render Mermaid diagrams
    in slides.
- **Other Things**
  - `favicons`: Favicons for various platforms and devices.
  - `Gemfile` & `Gemfile.lock`: Ruby dependencies for Jekyll and its plugins.
  - `_config.yml` & `_config.*.yml`: Main Jekyll configuration file and
    environment-specific overrides (Docker development, proxied development and
    standalone GitHub Pages builds). See [Configuration & Deployment
    Modes](#configuration--deployment-modes) and the explanations in each file.
  - `dashboard.txt`: Placeholder document to have the dashboard show up as an
    entry in search results.
  - `_includes`: Reusable Liquid templates for various parts of the
    site, including the sidebar, header, footer, and individual content blocks.
  - `_layouts`: Layout templates for different types of pages, such as the main
    layout, slide layout, exercise layout, and cheatsheet layout.
  - `src/assets/logging.ts`: Shared logging utilities for client-side scripts.
  - `src/scripts/**/*.ts`: TypeScript scripts for build-time tasks, such as
    generating PDFs and building the search index.
  - `src/shared/**/*.{ts,tsx}`: Common TypeScript code used in many client-side
    scripts and build-time tasks.
  - `tsconfig.json`: Base TypeScript configuration file.
  - `tsconfig.assets.json`: TypeScript configuration for client-side
    assets.
  - `tsconfig.scripts.json`: TypeScript configuration for build-time scripts.
  - `webpack.config.cjs`: Webpack configuration file for bundling client-side
    assets.

---

## Course Material

This section describes features and guidelines used in the actual course
materials.

### Writing Guidelines

- Use Markdown for formatting text, code blocks, lists, and other elements.
- Include images, diagrams, and other media to enhance understanding where
  appropriate.
- Ensure all links are valid and point to relevant resources.
- Link to a heading by the anchor slugged from its text — lowercased, with
  punctuation dropped and spaces turned into hyphens (`## Configure basic
settings` → `#configure-basic-settings`). The emoji shortcode a heading is
  decorated with is **not** part of its anchor: write `#create-your-server`, not
  `#exclamation-create-your-server`. (The Jekyll build still emits the shortcode
  in the anchor, so such a link scrolls nowhere until the Elixir renderer takes
  over; it still opens the right page.)
- Write an emoji either as its shortcode (`:books:`) or as the character itself
  (📚); the Elixir renderer draws both from the same file, so the two spellings
  are the same picture. The emoji the site has are a **closed set**, listed in
  [`app/lib/archidep/emoji.ex`][emoji]; the build reports any other one. Adding
  an emoji is an entry there plus an SVG, as
  [`theme/emoji/README.md`](../theme/emoji/README.md) describes. (Until the
  Elixir renderer takes over, Jekyll draws a shortcode as an image hotlinked
  from GitHub and leaves a character to whatever font the reader has.)
- Refer to a file sitting next to a document — an image, a PDF — by a plain
  relative path (`images/cli.jpg`, `./images/cli.jpg`, or `../images/cli.jpg`
  from a `slides.md` written at the root of its chapter, since a deck is
  published one directory deeper than it is written). The Elixir renderer
  resolves it to the digested name the file is published under, keeping the path
  shape written here, so a **missing file fails the build** rather than becoming
  a broken image. Its name, and every directory leading to it, must stick to
  letters, digits, `.`, `_` and `-` — the build rejects anything that would have
  to be percent-encoded. The file may be of any type: the diagrams published as
  PDFs next to an exercise work exactly as the images do. `{{ 'images/cli.jpg' |
relative_file_url }}` is no longer needed — the plain path is resolved wherever
  it is written — but the decks using it keep working.
- Use consistent terminology and style throughout the materials.
- Follow accessibility best practices to ensure content is usable by all
  students.

### Document Types

- A subject is a comprehensive document covering a specific topic, often
  including detailed explanations, examples, and exercises. It is meant to be
  read and studied in depth.
- Slides are more concise and visual, used for presentations or summarizing key
  points. They can be standalone (shown in the sidebar) or introduce a subject
  (embedded at the beginning of a subject).
- Exercises are practical tasks or problems for students to solve, often related
  to a subject. They can be graded or not. An exercise is always a chapter of
  its own: a chapter is either a subject or an exercise, never both, and an
  exercise never has slides (see [File Naming
  Conventions](#file-naming-conventions)).
- Cheatsheets are quick reference guides summarizing key concepts, commands,
  or procedures. They are meant to be used as a handy resource during study or
  practice.

### File Naming Conventions

Take care to respect the following conventions to ensure proper display,
ordering and identification of documents. The `_plugins/archidep.rb` plugin
relies on these conventions to extract metadata from filenames and directory
structures.

- Store subjects, slides and exercises in the [`collections/_course`
  directory](./collections/_course).
  - Name subdirectories with a three-digit numeric code followed by a short
    URL-friendly name, e.g. `101-introduction`, `201-deployment.md`,
    `202-git-basics.md`. The numeric code is used for ordering and
    identification.
  - The first digit of the numeric code indicates the section (1 for section 1,
    2 for section 2, etc). Sections are defined in the `_data/course.yml` file.
    The second and third digits indicate the order of documents within each
    section.
  - The main file in each subdirectory should be named `subject.md`, `slides.md`
    or `exercise.md` depending on the type of document.
  - A subdirectory must **never** contain both a `subject.md` and an
    `exercise.md` file: a chapter is one or the other. The two are published at
    the same URL, so a chapter holding both is an error rather than a chapter
    with two pages.
  - An exercise must **never** have slides. Only a subject may have accompanying
    slides, or the slides may stand alone in a chapter of their own.
  - A subject can also have accompanying slides. In this case, place a `slides`
    subdirectory next to the `subject.md` file, and put the `slides.md` file
    inside it.
  - Subjects, slides and exercices can have additional files, such as images or
    data files, placed in an `images` subdirectory next to their respective
    Markdown files.
- Store cheatsheets in the [`collections/_cheatsheets`
  directory](./collections/_cheatsheets).
  - Each cheatsheet should have its own subdirectory named with a short
    URL-friendly name, e.g. `command-line`, `git`.
  - The main file in each subdirectory should be named `cheatsheet.md`.
  - A cheatsheet can have additional files, such as images or data files, placed
    in an `images` subdirectory next to the `cheatsheet.md` file.
  - Every cheatsheet must be listed, in the order it should appear in, under the
    `cheatsheets` key of [`_data/course.yml`](./_data/course.yml). A cheatsheet
    that is not listed there, or a slug listed there with no such directory,
    **fails the build**: unlike a chapter, a cheatsheet has no number to be
    ordered by, so its position is a decision rather than something to derive.
    Jekyll reads the same order from the `collections.cheatsheets.order` key of
    [`_config.yml`](./_config.yml); keep the two in step until the Jekyll build
    is retired.

### Document Front Matter

Most document metadata is computed automatically by the
[`_plugins/archidep.rb`](./_plugins/archidep.rb) plugin from the filename and
directory structure (`num`, `section`, `course_type`, `permalink`, `layout`,
`progress`, `has_slides`, etc.). Do not set these keys manually, as they will be
overwritten. See [Custom Jekyll Plugins](#custom-jekyll-plugins).

The following front matter keys are meant to be set by authors:

- `title`: The document title. May include emoji shortcodes (rendered by
  [jemoji][jemoji]), e.g. `:rocket:`. **Required**: every document and
  cheatsheet must have one, and one without it fails the build. It is what the
  document is called in the sidebar, in a browser tab and in the name of its
  PDF, none of which has anywhere else to look. (Jekyll instead publishes those
  as blanks.)
- `graded: true`: Marks an exercise as graded. Graded exercises are flagged in
  the UI and indexed as a distinct `graded-exercise` type for search. Only an
  exercise may be graded: a subject, a slide deck or a cheatsheet declaring it
  fails the build rather than saying something that has no effect, and so does a
  value that is neither `true` nor `false`.
- `published: false`: Hides a work-in-progress document (standard Jekyll
  behaviour).
- `cloud_server: creation` or `cloud_server: details`: Embeds the [cloud server
  widget](#cloud-server-widget) in an exercise. Use `creation` on the exercise
  where students first create their server, and `details` on later exercises
  that only need to display the server's connection details.
- `sidebar_title`: An alternate, usually shorter, title for a **cheatsheet** to
  be listed under in the sidebar, since a cheatsheet's own title names the thing
  it is a cheatsheet of. It falls back to the title, and it is read from
  cheatsheets only.
- `excerpt_separator: <!-- more -->`: Marks the boundary of the excerpt shown at
  the top of a document. Write the separator itself in the body, where the
  excerpt is meant to end: a document that declares one and never writes it
  takes its whole body to be the excerpt.
- `standalone: false`: Excludes the document from the search index in
  [standalone builds](#configuration--deployment-modes) (e.g. content that only
  makes sense alongside the dashboard).
- `search_url`, `search_subtitle`, `search_extra_text`: Override the URL,
  subtitle and extra indexed text used when building the search data.

### Progress Tracking

How far the course has got is recorded in
[`app/priv/course/progress.json`](../app/priv/course/progress.json) — under the
dashboard application because both halves of the site read it from there — with
one entry per teaching session, in the order they were taught:

```json
{
  "sessions": [
    {
      "date": "2025-10-03",
      "title": "Git Branching and Collaborating",
      "done": [105, 200, 201, 202, 203],
      "due": [204, 205],
      "next": [300, 301, 400, 401, 402, 403]
    }
  ]
}
```

The numbers are the computed `num` of a document (e.g. `201`). To advance the
course, **append a session** rather than editing the ones already there; a
session may leave a category out.

The [`_plugins/archidep.rb`](./_plugins/archidep.rb) plugin aggregates the lists
across every session and assigns each chapter and section one of four progress
states, which drive the sidebar indicators, the home page cards, search
filtering and whether [solutions](#solutions) are shown:

- `done`: listed in any `done` array.
- `due`: listed in `due` but not yet `done`.
- `next`: listed in `next` but not `done` or `due`.
- `future`: not listed anywhere (the default).

### Special Tags and Features

This section describes special Liquid tags and features available for use in
course materials. Use them to enhance the content and improve the learning
experience.

#### Notes

The `note` tag creates a styled note box to highlight various kinds of
information. The following note types are available:

- `info`: Side note shown as a discreet gray box (default)
- `tip`: Helpful tip with a blue accent
- `warning`: Warning or caution with an orange accent
- `troubleshooting`: Troubleshooting advice with a red accent
- `more`: Additional information or resources with a green accent
- `advanced`: Advanced topic or challenge with a purple accent

Prefer adding a new line after the opening tag and before the closing tag for
better readability and to avoid issues when wrapping lines.

The `note` tag is implemented in the [`_plugins/tags/note.rb`
file](./_plugins/tags/note.rb).

**Example usage:**

```liquid
{% note type: tip %}

This is a helpful tip.

{% endnote %}
```

#### Callouts

The `callout` tag creates a styled callout box to draw attention to very
important information. It is much more prominent than a note and should be used
sparingly. The following callout types are available:

- `exercise`: Callout for an exercise or task with a blue accent
- `warning`: Warning with an orange accent, used for important cautions
- `danger`: Critical warning with a red accent, used for severe risks
- `more`: Additional information or resources with a green accent

Prefer adding a new line after the opening tag and before the closing tag for
better readability and to avoid issues when wrapping lines.

The `callout` tag is implemented in the [`_plugins/tags/callout.rb`
file](./_plugins/tags/callout.rb).

**Example usage:**

```liquid
{% callout type: warning %}

This is an important warning.

{% endcallout %}
```

A `more` callout requires an ID that is unique within the whole course:

```liquid
{% callout type: more, id: some-stuff %}

This is additional information with a unique ID.

{% endcallout %}
```

##### Tell Me More

`more` callouts are collapsible boxes that can be toggled open and closed. They
are collapsed by default, showing only the first few lines of content. A "Tell
me more" button can be clicked to expand the box and reveal the full content.

Use them to provide extensive additional information or resources that are not
essential for understanding the main content, but may be of interest to some
students.

Students can also choose to expand all `more` callouts at once from any open
`more` callout box. This setting is persisted to the browser's local storage, so
that all `more` callouts remain expanded on subsequent visits to the site.

#### Side-by-Side Columns

The `cols` tag creates responsive side-by-side columns to organize content
horizontally. It is useful for comparing two or more items, such as commands,
code snippets, or images. The content within the `cols` tag is split into
separate columns using the `<!-- col -->` delimiter. The columns are displayed
side-by-side on larger screens and stacked vertically on smaller screens for
better readability.

Prefer adding a new line after the opening tag and before the closing tag for
better readability and to avoid issues when wrapping lines.

The `cols` tag is implemented in the [`_plugins/tags/cols.rb`
file](./_plugins/tags/cols.rb).

**Example usage:**

```liquid
{% cols %}

This is the first column.

<!-- col -->

This is the second column.

{% endcols %}
```

More columns can be added by specifying the `columns` attribute:

```liquid
{% cols columns: 3 %}

This is the first column.

<!-- col -->

This is the second column.

<!-- col -->

This is the third column.

{% endcols %}
```

Classes can be added to each column within the `<!-- col -->` delimiter:

```liquid
{% cols %}

<!-- col text-red-500 -->

This is the first column with a custom class.

<!-- col text-center font-bold -->

This is the second column with multiple custom classes.

{% endcols %}
```

Note that the whitespace between the opening tag and the first delimiter is
ignored and not included in the first column.

#### Solutions

The `solution` tag creates a collapsible box, hidden by default, that reveals
its content when clicked. Use it to hide exercise solutions so students can
attempt the exercise first. It accepts an optional `title` attribute (default
"Solution").

The `solution` tag is implemented in the [`_plugins/tags/solution.rb`
file](./_plugins/tags/solution.rb).

A solution belongs to a chapter's exercise: writing one on the home page or in a
cheatsheet fails the build, since there is nothing there for it to answer. The
Elixir renderer additionally **leaves an answer out of the page entirely** until
the course has covered its chapter — see [Progress Tracking](#progress-tracking)
— because a page's source is there to be read, so a solution a student can find
by looking at the markup is not hidden at all.

**Example usage:**

```liquid
{% solution %}

Here is the solution to the exercise.

{% endsolution %}
```

#### Mermaid Diagrams

The `mermaid` tag renders a [Mermaid][mermaid] diagram from its content. The
diagram is rendered client-side (it shows a loading skeleton until then). Use
Mermaid for diagrams and visualizations where appropriate.

The `mermaid` tag is implemented in the [`_plugins/tags/mermaid.rb`
file](./_plugins/tags/mermaid.rb). Mermaid diagrams on slides are rendered by
[`src/assets/slides-mermaid.ts`](./src/assets/slides-mermaid.ts).

**Example usage:**

```liquid
{% mermaid %}
graph LR A[Client] --> B[Server]
{% endmermaid %}
```

#### Forced Markdown

The `markdown` tag wraps its content in a `<div class="markdown">` and forces
Markdown rendering of the block. It is useful when content nested inside raw
HTML would otherwise not be processed as Markdown. It is implemented in the
[`_plugins/tags/markdown.rb` file](./_plugins/tags/markdown.rb).

#### Code Blocks

Write code as a fenced block naming its language, which is what the block is
coloured by:

````markdown
```bash
$> echo "Hello"
```
````

A fence that names no language is shown as plain text rather than having its
language guessed at, which is what to write for the output of a command.

To draw the reader's eye to one line of a block, add the `highlight_lines`
decorator after the language. It takes line numbers and ranges of them,
separated by commas — `highlight_lines="4"`, `highlight_lines="1,3-5"` — and
gives each of those lines a background of its own:

````markdown
```bash highlight_lines="4"
$> pwd
/Users/Batman

$> cd .

$> pwd
/Users/Batman
```
````

It is the only decorator available, and a fence asking for anything else fails
the build.

Decorators are read by the site's own renderer, which is replacing Jekyll. Until
it serves the site, a fence carrying one renders as literal text: kramdown's
fenced block accepts a bare language and nothing else.

#### Cloud Server Widget

Setting `cloud_server: creation` or `cloud_server: details` in an exercise's
[front matter](#document-front-matter) embeds a live widget that displays the
student's cloud server details (username, IP address, SSH command, etc.) with
copy-to-clipboard buttons. The widget is rendered into a `cloud-server-data`
element by the [layout](./_layouts/toc.html) and driven by real-time updates
from the dashboard (see [Client-Side Architecture](#client-side-architecture)).
It is implemented as a Preact component in
[`src/assets/course/cloud-server.tsx`](./src/assets/course/cloud-server.tsx).

#### Randomized Values

Exercises can display example values (usernames, IP addresses, domains) that are
randomized and continuously change while on screen, to discourage students from
blindly copy-pasting and to encourage them to substitute their own values. Add a
raw HTML element with the `archidep-randomize` class next to the relevant code
block:

```html
<div
  class="archidep-randomize"
  data-regexp="(?<username>[a-z][a-z0-9]+)@(?<ipAddress>[a-z0-9]+(?:\.[a-z0-9]+){3})"
  data-template="<username>@<ipAddress>"
></div>
```

- `data-regexp`: A regular expression with named capture groups identifying the
  parts to randomize. Supported group names are `username`, `ipAddress` and
  `domain`.
- `data-template`: The template used to rebuild the text, referencing the groups
  with `<username>`, `<ipAddress>` and `<domain>` placeholders.
- `data-tooltip="false"`: Optionally disables the reminder tooltip.

This feature is implemented in
[`src/assets/course/randomize.ts`](./src/assets/course/randomize.ts).

#### Interactive Git Diagrams

Some slides and exercises embed interactive [Git memoir][git-memoir] diagrams
that animate Git operations (commits, branches, merges, push/pull) step by step.
Add a raw `<git-memoir>` element referencing a named diagram and a height:

```html
<git-memoir name="branching" svg-height="400px"></git-memoir>
```

The named diagrams are defined as factory functions in
[`src/assets/git-memoir/git-memoirs-registry.ts`](./src/assets/git-memoir/git-memoirs-registry.ts)
(registered on `window.gitMemoirs`), and rendered by the controller in
[`src/assets/git-memoir/git-memoir-controller.ts`](./src/assets/git-memoir/git-memoir-controller.ts).
Diagrams support several playback modes (autoplay, manual, visualization); see
[Slides](#slides) for their integration with reveal.js.

---

## General Coding Guidelines

The following guidelines concern the source code of the site at a general level.
See the next sections for more specific guidelines.

- **Main Frameworks, Languages and Libraries**
  - [Jekyll][jekyll] written in [Ruby][ruby] for static site generation
  - [Liquid][liquid] templating language for HTML generation
  - [Webpack][webpack] for bundling JavaScript and [TypeScript][typescript]
    scripts
  - [Preact][preact] and [Preact signals][preact-signals] with TSX for
    client-side interactive components
  - [Lunr][lunr] for full-text search
- **Liquid Guidelines**
  - Keep logic in Liquid templates minimal; prefer to handle complex logic in
    Ruby plugins. Look for refactoring opportunities as this may not currently
    be the case.
- **Client Assets Guidelines**
  - Use [Preact][preact] for interactive components
  - Use [Preact signals][preact-signals] for state management
  - Use modern ECMAScript features, transpiled to support modern browsers
  - Use [Prettier][prettier] for code formatting
- **TypeScript Guidelines**
  - Use strict typing and interfaces to ensure type safety.
  - Try to make impossible states unrepresentable.
  - Never use `any`. If you cannot know about the type of a value, create an
    [`io-ts` codec][io-ts-concepts] to validate it at runtime.
  - Use [ts-pattern][ts-pattern] for exhaustive pattern matching.

---

## Site Implementation

This section describes the technical implementation of the course material site.

### Custom Jekyll Plugins

The site relies on several custom plugins in the [`_plugins`](./_plugins)
directory:

- [`archidep.rb`](./_plugins/archidep.rb): The main plugin. Its `Generator`
  computes per-document metadata from filenames and the
  [`_data/course.yml`](./_data/course.yml) sections (`num`, `section`,
  `section_title`, `course_type`, `layout`, `permalink`, `progress`,
  `has_slides`, `toc`, etc.), links subjects to their slides, attaches items to
  their sections, and prepares the data shown on the [home page](#home-page).
  All of that but the progress is now also computed in Elixir by
  [`ArchiDep.CourseSite.Structure`][course-site-structure], which is what will
  replace this generator; the two agree, chapter for chapter, on the structure
  they describe. Its hooks also expose the application version and Git revision
  (read from `../app/mix.exs` and Git), render each document's `raw_markdown`
  (used by the [slide layout](#slides)), build the [search data](#search), and
  write the [JSON exports](#json-exports).
- [`utils.rb`](./_plugins/utils.rb): Shared `ArchiDep::Utils` helpers used by
  the custom tags — `render_markdown`, `render_icon` (renders an SVG from
  [`_includes/icons`](./_includes)) and the Markdown reference-link resolution
  used so that reference-style links keep working inside tags and slides.
- [`filters.rb`](./_plugins/filters.rb): Custom Liquid filters such as
  `collapse_whitespace`.
- [`relative_asset_url.rb`](./_plugins/relative_asset_url.rb): Liquid filters
  that resolve cache-busted asset URLs (see [Build Output & Asset
  URLs](#build-output--asset-urls)).

### Configuration & Deployment Modes

The base configuration is [`_config.yml`](./_config.yml). Notable settings:

- `destination: '../app/priv/static'`: The site is built directly into the
  dashboard application's static directory.
- `collections`: The `course`, `cheatsheets`, `json`, `progress` (and a reserved
  `notices`) collections, with `collections_dir: collections`.
- `plugins`: `jekyll-feed`, `jekyll-target-blank`, `jekyll-toc` and `jemoji`.
- `keep_files: [assets, cache_manifest.json]`: Preserves the assets and Phoenix
  cache manifest produced by the other build steps so Jekyll does not delete
  them when writing into `priv/static`.
- `archidep_standalone`, `archidep_years`, `archidep_repo` and similar custom
  keys used throughout the templates.

Environment-specific overrides are layered on top (e.g. `jekyll build --config
_config.yml,_config.proxied.yml`):

- [`_config.docker.yml`](./_config.docker.yml): Sets `host: 0.0.0.0` so the dev
  server is reachable from outside its Docker container.
- [`_config.proxied.yml`](./_config.proxied.yml): Forces the livereload script
  into the HTML so live reload works when the dashboard application serves the
  compiled files directly, bypassing the Jekyll server. This is the normal
  development setup (visit the site through the application).
- [`_config.pages.yml`](./_config.pages.yml): Builds the **standalone** site for
  GitHub Pages — sets `baseurl: '/website'` and `archidep_standalone: true`,
  which hides dashboard-only UI and excludes dashboard-only content from search.

### Build Output & Asset URLs

Client-side assets are bundled by [Webpack][webpack]
([`webpack.config.cjs`](./webpack.config.cjs)), which exports two
configurations:

- The main config bundles the `course`, `slides` and `slides-mermaid` entry
  points (and their CSS) into `app/priv/static/assets/course`.
- A second config bundles the `search` entry point into
  `app/priv/static/assets/search`.

**Cache busting is `phx.digest`'s, and the Phoenix `cache_manifest.json` is the
site's single asset manifest.** Entry bundles are therefore named plainly
(`course.js`), and the digest step — which runs over the whole static directory,
after every bundler has written into it — is what gives them a content-hashed
name and records it. Chunks Webpack loads at runtime are the exception: the
Webpack runtime requests those by name from its own `publicPath` and never
consults a manifest, so they keep Webpack's `[chunkhash]`.

The [`relative_asset_url.rb`](./_plugins/relative_asset_url.rb) plugin reads
`cache_manifest.json` so templates can reference assets by their logical name
and get the correct hashed URL. **Do not hardcode hashed asset paths in
templates** — use the asset-url filters instead. In development, where nothing
is digested, the filters fall back to the plain path.

### JSON Exports

The following JSON files are written into the application's static directory
during the build for integration with (and archival of) the dashboard
application:

- The course structure is exported to `app/priv/static/archidep.json` (from
  [`collections/_json/archidep.json.liquid`](./collections/_json)), which the
  PDF generation script reads to know which pages to print. The dashboard
  application no longer reads it: it compiles its own model of the course from
  the Markdown sources. The Elixir build writes the same file, under the edition
  prefix of whatever directory it was given, and adds what each page's PDF is
  called; its URLs are the build's own even when the build's pages link to the
  deployed site, because the file describes the copy the export is about to
  walk. See [PDF Generation](#pdf-generation).
- What the search dialog can find is exported to `app/priv/static/search.json`,
  so that the dashboard application can offer the same search over the same
  material. The Elixir build writes the same file under the edition prefix and
  under a name carrying the identifier of the build that produced it, which it
  must: the index is read _off_ the pages whose `<head>` names it, so it cannot
  be named after its own contents. See [Search](#search).
- Build metadata (application version, Git branch and revision) is exported to
  `app/priv/static/version.json`.

### Client-Side Architecture

The main client entry point is
[`src/assets/course.ts`](./src/assets/course.ts), bundled by Webpack and loaded
on every page. It initializes the interactive features ([search](#search),
copy buttons, [randomized values](#randomized-values), the [cloud server
widget](#cloud-server-widget), the table of contents, "back to top", [tell me
more](#tell-me-more), [Git memoirs](#interactive-git-diagrams)) and the
real-time integration described below. Components are built with
[Preact][preact] and [Preact signals][preact-signals]; external JSON is
validated at runtime with [`io-ts`][io-ts] codecs (see
[`src/shared/codecs`](./src/shared)). Logging goes through
[`src/assets/logging.ts`](./src/assets/logging.ts) ([loglevel][loglevel]).

**Real-time dashboard integration.** When not in standalone mode, the client
opens a [Phoenix][phoenix] WebSocket channel to the dashboard application
(authenticated via a token fetched from the application). Through this channel
it receives the current session and live cloud server data, reconnecting
automatically with exponential backoff. The session is cached in `localStorage`
and modelled as a small state machine (anonymous, cached, connected, connection
error) in [`src/assets/course/session.ts`](./src/assets/course/session.ts); it
drives the login/logout/impersonation UI and the [cloud server
widget](#cloud-server-widget). In standalone builds, this integration and
analytics are disabled.

### Search

Full-text search uses [Lunr][lunr]. At build time, one searchable element is
extracted for each document and for each of its top-level headings and written
to `search.json` — by the [`archidep.rb`](./_plugins/archidep.rb) plugin under
Jekyll, and by `ArchiDep.CourseSite.Build.SearchIndex` under the Elixir
renderer.

The Lunr index itself is **not** built at build time and not downloaded: on the
client, [`src/assets/course/search.ts`](./src/assets/course/search.ts) lazily
loads `search.json` and builds the index in the browser (boosting the
`extraText` field and keeping match positions for highlighting). A serialised
index is five times the size of the data it is built from, and building it takes
a fraction of what downloading that would cost — a couple of hundred
milliseconds for the whole course, against megabytes that would otherwise cross
the network before the first search.

The page says where the index is, as a whole URL in `data-search-data-url`,
because its name carries the identifier of the build that wrote it and no script
can work that out. The dialog is rendered from the `*.template.html` templates
and supports keyboard activation (<kbd>Ctrl</kbd>/<kbd>Cmd</kbd>+<kbd>K</kbd>)
and quick shortcuts. Its own icons are the site's own emoji
([`app/lib/archidep/emoji.ex`][emoji]): the page leaves them in a hidden element
for the script to take, since only the build knows what an emoji file is called
once it has been digested.

### Slides

Slides are presented with [reveal.js][reveal], configured in
[`src/assets/slides.ts`](./src/assets/slides.ts) (Markdown, highlight, notes and
search plugins). The slide [layout](./_layouts) feeds the document's
pre-rendered `raw_markdown` into reveal.js. Mermaid diagrams are rendered lazily
per slide by
[`src/assets/slides-mermaid.ts`](./src/assets/slides-mermaid.ts), and
[interactive Git diagrams](#interactive-git-diagrams) are wired into the slide
lifecycle by [`src/assets/slides/git-memoirs.ts`](./src/assets/slides). Useful
query parameters include `?print-pdf` (PDF export layout), `?view=scroll`
(continuous scroll) and `?show-notes`.

### PDF Generation

The `npm run pdf` script ([`src/scripts/pdf.ts`](./src/scripts/pdf.ts))
generates PDF versions of the course materials using [Puppeteer][puppeteer]. It
prints a **local build**: it reads that build's `archidep.json` to know which
pages to print and what each PDF is called, serves the build over loopback
itself, drives a headless browser to each page and slide deck (with the
appropriate query parameters), and writes the PDFs into the output directory,
emptying it first.

```bash
npm run pdf -- --build tmp/pdf-build --output tmp/pdf
```

Both `--build` and `--output` are required — the script assumes nothing about
where either sits. It also accepts `--manifest <file>` (when the build holds
more than one `archidep.json`, or none where they are looked for), `--base-url
<url>` (print a site that is already being served rather than serving the
build), and `--port <n>` (pin the throwaway server's port instead of taking any
free one).

**Nothing has to be running, and no page ever reaches the deployed site.** The
links printed inside the PDFs are whatever the build baked into them, so the
build that is printed is the one made with `--absolute-base-url`:

```bash
cd app && mix archidep.course_site.build \
  --output ../tmp/pdf-build --clean \
  --absolute-base-url https://archidep.ch \
  --pdf-base https://example.com/where/the/pdfs/are/published
```

Such a build must not set `--base-path`: the export maps URL paths straight onto
the build directory, and a mount point would put a prefix in every URL that the
served tree does not have. See the [renderer's own
documentation](../app/lib/archidep/course_site/CONTRIBUTING.md#generated-pdfs)
for what decides the PDF names and where they are published.

Those two commands are also what the [`pdf`
workflow](../.github/workflows/pdf.yml) runs, on every change to `main` that
could reach a PDF, so the published PDFs of the current edition are always the
current material. It can be run by hand from the Actions tab as well.

As noted in the [`AGENTS.md`](./AGENTS.md), this is an expensive operation; run
it locally only when you need the files themselves.

### Home Page

The home page ([`index.md`](./index.md), `home` layout) summarizes course
progress with three cards — what was covered previously, what is due next, and
what is coming up — built from the most recent [progress
documents](#progress-tracking) by the [`archidep.rb`](./_plugins/archidep.rb)
plugin (`previous_chapters`, `next_due_exercises`, `next_chapters`).

---

## Formatting and Linting

- Use [Prettier][prettier] for formatting Liquid templates as well as Ruby and
  TypeScript code.

---

## References

- [Jekyll][jekyll] for static site generation
  - [Jekyll Documentation][jekyll-docs]
- [Liquid Documentation][liquid] for HTML templating
- [Git memoir][git-memoir] for interactive Git diagrams
- [io-ts][io-ts] for runtime type checking and validation
  - [io-ts Documentation][io-ts-docs]
- [jemoji][jemoji] for emoji shortcode rendering
- [Loglevel][loglevel] for client-side logging
- [Lunr][lunr] for full-text search
- [Mermaid][mermaid] for diagrams and visualizations
- [Phoenix][phoenix] for real-time integration with the dashboard application
- [Plausible Analytics][plausible] for privacy-friendly web analytics
- [Preact][preact] for client-side interactivity
  - [Preact Signals][preact-signals] for state management
- [Prettier Documentation][prettier] for code formatting
- [Puppeteer][puppeteer] for PDF generation
- [Reveal][reveal] for slide presentations
- [Ruby][ruby]
  - [Ruby Documentation][ruby-docs]
- [TypeScript][typescript]
  - [ts-pattern][ts-pattern] for exhaustive pattern matching
- [Webpack][webpack] for bundling JavaScript and TypeScript
  - [Webpack Documentation][webpack-docs]

---

## For AI Agents

Follow the instructions and guidelines in this document and read the adjacent
[`AGENTS.md`](./AGENTS.md) file for additional instructions targeted towards AI
agents.

[iconify]: https://github.com/iconify/iconify
[io-ts]: https://github.com/gcanti/io-ts
[io-ts-concepts]: https://gcanti.github.io/io-ts/
[io-ts-docs]: https://github.com/gcanti/io-ts/blob/master/index.md
[git-memoir]: https://github.com/AlphaHydrae/git-memoir
[jekyll]: https://jekyllrb.com
[jekyll-docs]: https://jekyllrb.com/docs
[course-site-structure]: ../app/lib/archidep/course_site/structure.ex
[emoji]: ../app/lib/archidep/emoji.ex
[jemoji]: https://github.com/jekyll/jemoji
[liquid]: https://shopify.github.io/liquid/
[phoenix]: https://hexdocs.pm/phoenix/Phoenix.Channel.html
[loglevel]: https://github.com/pimterry/loglevel
[lunr]: https://lunrjs.com
[mermaid]: https://mermaid.js.org
[plausible]: https://plausible.io
[preact]: https://preactjs.com
[preact-signals]: https://preactjs.com/guide/v10/signals/
[prettier]: https://prettier.io
[puppeteer]: https://pptr.dev
[reveal]: https://revealjs.com
[ruby]: https://www.ruby-lang.org
[ruby-docs]: https://www.ruby-lang.org/en/documentation/
[ts-pattern]: https://github.com/gvergnaud/ts-pattern
[typescript]: https://www.typescriptlang.org
[webpack]: https://webpack.js.org
[webpack-docs]: https://webpack.js.org/concepts/
