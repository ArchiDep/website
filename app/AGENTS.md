# AGENTS.md

The main contribution guidelines for both humans and AI agents are documented in
the adjacent [`app/CONTRIBUTING.md`](./CONTRIBUTING.md) file. This document
provides additional instructions and guidelines targeted towards AI assistants
and automated agents interacting with this project.

---

## AI Assistant Instructions

- Do not edit generated files that are ignored (documented in the [application
  structure](./CONTRIBUTING.md#application-structure)), although you may want
  to look in the `priv/static/` directory to understand how static assets are
  organized.
- Avoid changes to configuration files (`config/`) unless requested or
  required for a specific feature, because changing them causes a recompilation
  of the entire project. Ask for confirmation if it proves necessary to change
  them.
- When changing the public API of application contexts, update the relevant
  documentation in the appropriate `CONTRIBUTING.md` file.
- There should generally be no need to add a new bounded context without
  explicit instructions from a human. If you believe a new context is needed,
  explain why in your response and ask for confirmation.
