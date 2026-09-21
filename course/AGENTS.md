# AGENTS.md

The main contribution guidelines for both humans and AI agents are documented in
the adjacent [`course/CONTRIBUTING.md`](./CONTRIBUTING.md) file. This document
provides additional instructions and guidelines targeted towards AI assistants
and automated agents interacting with this project.

---

## AI Assistant Instructions

- The Liquid tags in the Markdown of this directory are implemented in
  [`ArchiDep.CourseSite.Renderer`](../app/lib/archidep/course_site/CONTRIBUTING.md).
  A tag that does not exist there does not exist.
- **Keeping [tutor notes](./CONTRIBUTING.md#tutor-notes) in step with the course
  material is your responsibility** whenever you change a chapter, as that
  section describes. Update the notes in the same change rather than leaving it
  to the human, and tell the human reviewer which notes you changed and anything
  in them you could not check, such as an expected output you could not run.
  Only keep existing notes up to date: writing a chapter's notes from scratch is
  a task of its own, done when asked.
- **Run the [script tests](./CONTRIBUTING.md#exercise-scripts) yourself** when a
  change touches what they play, and report their result. If you cannot run
  one, say so instead of reporting the change as done.
