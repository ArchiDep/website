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

## Course Material Guidelines

TODO: notes, callouts, tell me more, cloud server, randomization (chance), revealjs, real slides

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
- **Client Assets Guidelines**
  - Use [Preact][preact] for interactive components
  - Use [Preact signals][preact-signals] for state management
  - Use modern ECMAScript features, transpiled to support modern browsers
  - Use [Prettier][prettier] for code formatting
- **TypeScript Guidelines**
  - Use strict typing and interfaces to ensure type safety.
  - Try to make impossible states unrepresentable.
  - Use
- **Liquid Guidelines**
  - Keep logic in Liquid templates minimal; prefer to handle complex logic in
    Ruby plugins. Look for refactoring opportunities as this may not currently
    be the case.

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
  - [ts-pattern][ts-pattern] for exhaustive pattern matching in TypeScript
- [Webpack][webpack] for bundling JavaScript and TypeScript
  - [Webpack Documentation][webpack-docs]

---

## For AI Agents

Follow the instructions and guidelines in this document and read the adjacent
[`AGENTS.md`](./AGENTS.md) file for additional instructions targeted towards AI
agents.

[iconify]: https://github.com/iconify/iconify
[io-ts]: https://github.com/gcanti/io-ts
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
