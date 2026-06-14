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
  test support inventory, formatting and linting, commands:
  [`app/CONTRIBUTING.md`](./app/CONTRIBUTING.md)
  - Testing conventions — how we write tests (exact assertions, fixtures, mocks,
    deterministic time, per-layer patterns):
    [`app/docs/testing.md`](./app/docs/testing.md)
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
  - When a reviewer points out that you missed a documented guideline or
    convention, treat it as a process problem, not just a one-off fix. Take the
    time to work out _why_ it was missed and what durable change would stop it
    recurring — clarifying the guideline itself, the relevant docs, or these
    instructions — then apply or proactively propose that change in the same
    turn, in addition to fixing the specific instance.

- **Editing Behavior**
  - Never make commits; a human will review and commit changes.
  - Do not modify files in the `tmp/` directory unless explicitly instructed.
  - If you do include cultural references as indicated in the `CONTRIBUTING.md`
    file, tell the human reviewer about them and where they come from.
  - When generating Markdown, prefer reference links over inline links for URLs
    and anchors if there are at least two occurrences of the same URL or anchor
    in the document.
  - When writing or modifying tests, follow the conventions in
    [`app/docs/testing.md`](./app/docs/testing.md).
  - **You are forbidden to write any partial test assertion without first
    stopping and analyzing the testing guidelines.** A partial assertion is any
    assertion that checks a subset of a value instead of the whole — e.g. a
    pattern match binding only some fields, or asserting only some fields,
    instead of full-struct/exact equality. Before writing ANY such assertion you
    MUST stop and read the relevant sections of
    [`app/docs/testing.md`](./app/docs/testing.md) (read them — do not skim, and
    do not assume the rule fails to apply to your change) to check whether they
    grant a **specific** exception for that case. If a specific exception
    applies, follow it. If none does, you are **ABSOLUTELY FORBIDDEN** to write
    the assertion on your own judgement: you may argue that an exception is
    warranted, but you must get **EXPLICIT** prior approval from a human before
    making the change. Avoiding duplication is never a justification — use a
    helper that builds a well-known shape and accepts overrides so each test
    still asserts the whole value by equality.
  - **Code and test comments exist to explain the _purpose_ of the code as it
    stands now** — what it does and why, for a reader who has no other context.
    A comment that would be wrong or meaningless once some _other_ artifact
    changes is a comment that will rot. Concretely, a comment **must not**:
    - **Reference a short-lived document or its sections** — work-in-progress
      backlogs (`wip/*.md`), future-work docs, planning notes, or "see the X
      task/backlog". These disappear and you will not remember to update the
      comment. (Stable docs such as `app/docs/testing.md` _may_ be cited.) Do
      not mention task-tracking concerns either (e.g. which checkbox a change
      covers).
    - **Duplicate the testing guidelines.** Do not restate rules from
      `app/docs/testing.md` in a test file or support module; cite the doc at
      most. The reviewer will remove duplicated guidance.
    - **Record historical rationale** — why the code was changed, a past bug it
      fixes, what it "used to" do, or that a typo "was" mistyped. That belongs
      in the commit message, not the code. The one exception is a **regression
      test**, where describing the past behaviour is what makes the test
      meaningful.
  - **Before you finish any task that adds or changes tests, run an explicit
    self-audit of your diff** — do not declare the work done until you have:
    1. **Listed every assertion you added or changed and classified each one.**
       Any assertion that is not a whole-value equality (`==`) is suspect:
       - Single-field check (`assert x.field == v`)
       - Partial map/struct pattern used as the assertion:
         - `assert %{k: v} = map`
         - `assert {:ok, %S{f: ^v}} = ...`
       - `errors_on(cs)` matched with `=` instead of `==`
       - asserting only some fields of a returned value

       For each, either rewrite it to assert the whole value by equality, or
       confirm a **specific** documented exception applies (re-read
       `app/docs/testing.md`; do not rely on memory). If neither, you are
       **FORBIDDEN** to keep it without **EXPLICIT** human approval — flag it
       and ask.

    2. **Re-read every comment you added** against the comment rules above and
       deleted or rewritten any that reference a short-lived doc, duplicate the
       guidelines, or record historical rationale. This audit is mandatory and
       is the last step before reporting completion — these rules existed and
       were still violated, so treat the audit as the enforcement mechanism, not
       the prose alone.

  - After editing Markdown documentation, run `npm run lint:md` (documented in
    [`./CONTRIBUTING.md`][contributing]) and fix any reported issues.
  - When you complete a task tracked by a checkbox in a backlog document (such
    as `wip/testing.md`), check its box (`- [ ]` → `- [x]`) as part of the same
    change.

- **Commands**
  - Do not execute the `npm run pdf` command documented in
    [`./CONTRIBUTING.md`][contributing]. It is an expensive operation that
    generates PDF files for all course slides. A human will run this command
    when needed.

[contributing]: ./CONTRIBUTING.md
