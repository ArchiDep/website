# AGENTS.md

This file provides instructions and guidelines for AI assistants and automated
agents interacting with this project.

---

## Contribution guidelines

Read the following files to understand how this project is structured and what
guidelines to follow when contributing:

- [CONTRIBUTING.md][contributing]: General contribution guidelines for the
  entire project.
- [app/CONTRIBUTING.md](./app/CONTRIBUTING.md): Contribution guidelines
  specific to the dashboard application.
- [app/AGENTS.md](./app/AGENTS.md): Additional instructions for AI agents
  working within the dashboard application.
- [course/CONTRIBUTING.md](./course/CONTRIBUTING.md): Contribution guidelines
  specific to the course material site.
- [course/AGENTS.md](./course/AGENTS.md): Additional instructions for AI agents
  working within the course material site.
- [theme/CONTRIBUTING.md](./theme/CONTRIBUTING.md): Contribution guidelines
  specific to the Tailwind CSS theme.
- [theme/AGENTS.md](./theme/AGENTS.md): Additional instructions for AI agents
  working within the Tailwind CSS theme.

`CONTRIBUTING.md` documents are for both humans and AI agents. They are to take
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
  - When changing the public API of application contexts, update the relevant
    documentation in the appropriate `CONTRIBUTING.md` file.
  - There should generally be no need to add a new bounded context without
    explicit instructions from a human. If you believe a new context is needed,
    explain why in your response and ask for confirmation.

- **Commands**
  - Do not execute the `npm run pdf` command documented in
    [`./CONTRIBUTING.md`][contributing]. It is an expensive operation that
    generates PDF files for all course slides. A human will run this command
    when needed.

- **External Resources**
  - Read linked documentation in this file and in subdirectory-specific
    `AGENTS.md` and `CONTRIBUTING.md` files to better understand the languages,
    frameworks and libraries used in this project, as well as the architecture,
    conventions and standards to follow.
  - Do not hesitate to read and quote this information in the context of your
    changes.

[contributing]: ./CONTRIBUTING.md
