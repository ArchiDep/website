# AGENTS.md

This file provides instructions and guidelines for AI assistants and automated
agents interacting with this project.

---

## Contribution guidelines

Use this map to jump straight to the right documentation instead of reading
every file. Each `CONTRIBUTING.md` is the source of truth for its component and
has its own table of contents; the entries below are starting points, not an
exhaustive index.

- **Whole project** — repository layout, cross-component tooling, project-wide
  coding and security guidelines: [`CONTRIBUTING.md`][contributing]
- **Course material site** — writing guidelines, document types, front matter,
  Liquid/Jekyll, slides, PDF generation:
  [`course/CONTRIBUTING.md`](./course/CONTRIBUTING.md)
- **Theme** — Tailwind/DaisyUI, dark mode, typography, syntax highlighting:
  [`theme/CONTRIBUTING.md`](./theme/CONTRIBUTING.md)
- **Dashboard application** — overall architecture, development environment,
  testing, formatting and linting, commands:
  [`app/CONTRIBUTING.md`](./app/CONTRIBUTING.md)
  - Bounded context anatomy (how every context is structured):
    [`app/CONTRIBUTING.md`](./app/CONTRIBUTING.md#bounded-contexts)
  - Web layer — routing, LiveView, components, i18n, admin console, server UI:
    [`app/lib/archidep_web/CONTRIBUTING.md`](./app/lib/archidep_web/CONTRIBUTING.md)
  - Accounts context — user accounts, sessions, Switch edu-ID/OIDC
    authentication, login links, impersonation:
    [`app/lib/archidep/accounts/CONTRIBUTING.md`](./app/lib/archidep/accounts/CONTRIBUTING.md)
  - Course context — classes and students, student import, expected server
    properties:
    [`app/lib/archidep/course/CONTRIBUTING.md`](./app/lib/archidep/course/CONTRIBUTING.md)
  - Servers context — cloud servers, server groups, server tracking, Ansible
    pipeline:
    [`app/lib/archidep/servers/CONTRIBUTING.md`](./app/lib/archidep/servers/CONTRIBUTING.md)
  - Events context — event sourcing and audit log (covered in the app
    documentation, no separate file):
    [`app/CONTRIBUTING.md`](./app/CONTRIBUTING.md#events--auditing)

For AI-specific instructions within a component, also read its `AGENTS.md`:
[`app/AGENTS.md`](./app/AGENTS.md), [`course/AGENTS.md`](./course/AGENTS.md) and
[`theme/AGENTS.md`](./theme/AGENTS.md).

`CONTRIBUTING.md` documents are for both humans and AI agents. They take
precedence over instructions in the `AGENTS.md` files, which contain additional
instructions targeted towards AI agents.

---

## AI Assistant Instructions

- **General Guidance**
  - Explain your reasoning for any non-trivial code edits or suggestions.
  - When in doubt, ask for clarification or provide options.

- **Editing Behavior**
  - Never make commits; a human will review and commit changes.
  - Do not modify files in the `tmp/` directory unless explicitly instructed.
  - If you do include cultural references as indicated in the `CONTRIBUTING.md`
    file, tell the human reviewer about them and where they come from.
  - When generating Markdown, prefer reference links over inline links for URLs
    and anchors if there are at least two occurrences of the same URL or anchor
    in the document.
  - After editing Markdown documentation, run `npm run lint:md` (documented in
    [`./CONTRIBUTING.md`][contributing]) and fix any reported issues.

- **Commands**
  - Do not execute the `npm run pdf` command documented in
    [`./CONTRIBUTING.md`][contributing]. It is an expensive operation that
    generates PDF files for all course slides. A human will run this command
    when needed.

[contributing]: ./CONTRIBUTING.md
