# Contributing

Please read this document to understand how the ArchiDep course material site is
structured and what guidelines to follow when contributing.

The adjacent [`AGENTS.md`](./AGENTS.md) file contains additional instructions
for AI assistants and automated agents.

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
    the materials are organized.
  - `collections/_cheatsheets`: Cheatsheets for students to quickly reference
    key concepts and commands.
  - `collections/_json`: JSON data exports for integration with the dashboard
    application.
  - `collections/_progress`: Progress posts to track course completion during
    the semester, utilizing the numbering scheme of the main course materials.
- **Important Files**
  - `_plugins/archidep.rb`: Custom Jekyll plugin to enrich documents with
    additional metadata, such as determining the type of document (subject,
    slide, exercise, cheatsheet) and extracting the numeric code from filenames,
    building the search data, and various other things.
  - `_plugins/tags/**/*.rb`: Custom Liquid tags to spruce up course content,
    such as callout boxes, styled notes, responsive side-by-side columns,
    mermaid diagrams, and more.
  - `src/assets/course.ts` & `src/assets/course/**/*.{ts,html}`: TypeScript and
    HTML files for client-side interactivity, such as copy-to-clipboard buttons,
    analytics, search functionality, and more.
  - `src/assets/git-memoir/**/*.ts`: TypeScript definitions of interactive Git
    diagrams shown in some slides and exercises, and a renderer to display them.
  - `src/assets/slides.ts`: TypeScript file to enhance slide presentations with
    features like Git diagrams.
  - `src/assets/slides-mermaid.ts`: TypeScript file to render Mermaid diagrams
    in slides.
- **Other Things**
  - `favicons`: Favicons for various platforms and devices.
  - `Gemfile` & `Gemfile.lock`: Ruby dependencies for Jekyll and its plugins.
  - `_config.yml` & `_config.*.yml`: Main configuration file and configuration
    overrides for Jekyll. See the explanations in each file.
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
  to a subject. They can be graded or not.
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

### Progress Tracking

Progress during the course is visually indicated in the sidebar as a colored
border next to each subject, slide and exercise. Three cards

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

TODO: cloud server, randomization (chance), revealjs, progress tracking

- Use [Mermaid][mermaid] for diagrams and visualizations where appropriate.

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

### Home Page

TODO

### JSON Exports

The following JSON files are exported during the build process for integration
with the dashboard application:

- The course structure is exported to `app/priv/static/archidep.json` so that
  the dashboard application can replicate the sidebar markup and navigation.
- The full-text search index built with [Lunr][lunr] is exported to
  `app/priv/static/lunr.json` so that the dashboard application can perform
  the same client-side search.
- The source data used to build the search index is exported to
  `app/priv/static/search.json` so that the dashboard application can display
  the same search results interface.

TODO: [Iconfify][iconify]

---

## Formatting and Linting

- Use [Prettier][prettier] for formatting Liquid templates as well as Ruby and
  TypeScript code.

---

## References

- [Jekyll][jekyll] for static site generation
  - [Jekyll Documentation][jekyll-docs]
- [Liquid Documentation][liquid] for HTML templating
- [io-ts][io-ts] for runtime type checking and validation
  - [io-ts Documentation][io-ts-docs]
- [Loglevel][loglevel] for client-side logging
- [Lunr][lunr] for full-text search
- [Mermaid][mermaid] for diagrams and visualizations
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
[jekyll]: https://jekyllrb.com
[jekyll-docs]: https://jekyllrb.com/docs
[liquid]: https://shopify.github.io/liquid/
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
