# Contributing

This document describes the **Course bounded context** of the ArchiDep dashboard
application. It is part of the application documented in the
[`app/CONTRIBUTING.md`][app-contributing] file at the application root, which
covers the overall architecture, the general [bounded context
anatomy][bounded-contexts], coding guidelines, [authorization][authorization]
and tooling that also apply here. Read that document first.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Overview](#overview)
- [Context Structure](#context-structure)
- [Domain Model](#domain-model)
- [Classes](#classes)
- [Students](#students)
  - [Student Import](#student-import)
  - [Username Confirmation](#username-confirmation)
- [Expected Server Properties](#expected-server-properties)
- [Course Material Integration](#course-material-integration)
- [Use Cases](#use-cases)
- [Business Events](#business-events)
- [Authorization](#authorization)
- [References](#references)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

---

## Overview

The Course context (`ArchiDep.Course`, [`course.ex`](../course.ex) /
[`context.ex`](./context.ex)) manages **classes and students** and their related
configuration, and exposes the **course material** structure to the application.

Key concepts a contributor must understand:

- **Classes and students.** A [`Class`](./schemas/class.ex) is a cohort (a
  teaching class for a given semester); a [`Student`](./schemas/student.ex)
  belongs to a class. Teachers create classes and add students individually or
  by [bulk import](#student-import).
- **This context owns the `classes` and `students` tables.** The [Accounts
  context](../accounts/CONTRIBUTING.md#domain-model) reads those same tables (as
  `UserGroup` and `PreregisteredUser`) for authentication. Course is the system
  of record for enrollment; Accounts observes it. When changing those tables,
  consider both contexts.
- **Preregistration.** A student record exists **before** the person logs in.
  When they first authenticate, the Accounts context links the student to a
  newly created user account by email. A [`User`](./schemas/user.ex) read-view
  of `user_accounts` ties a login back to its student.
- **Expected server properties.** Each class defines the [expected
  properties](#expected-server-properties) of the cloud servers its students
  will create, used to flag misconfigured servers.
- **Course material.** The context exposes the structure of the Jekyll [course
  material site](../../../../course/CONTRIBUTING.md) (sections, documents,
  cheatsheets) via [`Material`](#course-material-integration).
- **Authorization is simple:** teachers are **root** users and may do anything;
  students may only read their own record and confirm their own username (see
  [Authorization](#authorization)).

---

## Context Structure

The context follows the standard [bounded context anatomy][bounded-contexts]:

- **Public API** — [`course.ex`](../course.ex) delegates to
  [`context.ex`](./context.ex) (which implements [`behaviour.ex`](./behaviour.ex)),
  which in turn routes each operation to a [use case](#use-cases). See [Use
  Cases](#use-cases) for the operations and the module that implements each.
- **Types** — [`types.ex`](./types.ex) (class, student, import and expected
  server properties data).
- **Schemas** — [`schemas/`](./schemas), see [Domain Model](#domain-model).
- **Use cases** — [`use_cases/`](./use_cases), see [Use Cases](#use-cases).
- **Policy** — [`policy.ex`](./policy.ex), see [Authorization](#authorization).
- **Events** — [`events/`](./events), see [Business Events](#business-events).
- **PubSub** — [`pub_sub.ex`](./pub_sub.ex) broadcasts class and student changes
  on the `classes`, `classes:{id}`, `classes:{id}:students` and `students:{id}`
  topics.
- **Course material** — [`material.ex`](./material.ex) and
  [`helpers/material_helpers.ex`](./helpers/material_helpers.ex) (not part of
  the standard anatomy), see [Course Material
  Integration](#course-material-integration).

---

## Domain Model

The context's schemas and the database tables they back:

- [`Class`](./schemas/class.ex) (`classes`): A cohort of students (see
  [Classes](#classes)). Owns one `ExpectedServerProperties`.
- [`Student`](./schemas/student.ex) (`students`): A student in a class (see
  [Students](#students)). Optionally linked to a `User` once they log in.
- [`ExpectedServerProperties`](./schemas/expected_server_properties.ex)
  (`server_properties`): The expected hardware/OS profile for a class's servers
  (see [Expected Server Properties](#expected-server-properties)).
- [`StudentImportList`](./schemas/student_import_list.ex) (embedded, no table):
  Validates and prepares a [bulk student import](#student-import).
- [`User`](./schemas/user.ex) (`user_accounts`): A read-view of the account that
  links a login to its `Student`. The [Accounts
  context](../accounts/CONTRIBUTING.md) owns the write side of this table.

`Class` and `Student` are the **write side** of the `classes` and `students`
tables that the [Accounts context](../accounts/CONTRIBUTING.md#domain-model)
reads as `UserGroup` and `PreregisteredUser`.

---

## Classes

A [`Class`](./schemas/class.ex) represents a teaching class/cohort. Besides its
`name`, a class carries:

- An optional `start_date`/`end_date` window and an `active` flag. A class is
  **active** only when `active` is true and the current date is within the
  window; an inactive class disables its students.
- `servers_enabled` — whether students of the class may create cloud servers
  (combined with the active state by `allows_server_creation?/2`).
- `teacher_ssh_public_keys` — SSH keys authorized to connect to the students'
  servers (so teachers can help).
- MD5/SHA-256 host-key fingerprints of the shared **SSH exercise VM** used early
  in the course.
- An associated [`ExpectedServerProperties`](#expected-server-properties).

Classes are managed by teachers (root users) — see [Use Cases](#use-cases). A
class cannot be deleted while it still has servers.

---

## Students

A [`Student`](./schemas/student.ex) belongs to a class and represents an
enrolled participant. Notable fields:

- `name`, `email` (unique within the class), and an optional `academic_class`.
- `username` and `username_confirmed` — the student's chosen login/server
  username and whether they have confirmed it (see [Username
  Confirmation](#username-confirmation)).
- `domain` — the domain under which the student's servers live; the student's
  server hostname is `username.domain` (e.g. `jde.archidep1.ch`).
- `active` and `servers_enabled` — per-student activation and server permission
  (a student may create servers when active and either their own or the class's
  `servers_enabled` is set).
- `ssh_exercise_password` — a generated password for the shared SSH exercise VM.
- An optional `user` association, populated once the student logs in.

A student exists before first login (**preregistration**); the [Accounts
context](../accounts/CONTRIBUTING.md) links it to a user account on login.

### Student Import

Teachers can bulk-import students into a class with `import_students/3`. The
[`StudentImportList`](./schemas/student_import_list.ex) embedded schema
validates the payload (a required `domain`, an optional `academic_class`, and a
list of `{name, email}` students) and prepares the rows to insert:

- Students are **de-duplicated by email**, and the insert ignores rows that
  conflict with existing students.
- A **suggested username is generated** for each student, avoiding collisions
  with usernames already in the class — derived from the email local part when
  possible (e.g. `john.doe@…` → `jd`, `jd1`, …), otherwise random.
- Each student gets a generated `ssh_exercise_password`, and is created with
  `username_confirmed: false`.

The import emits one [`StudentCreated`](./events/student_created.ex) event per
new student plus a
[`StudentsImportedInClass`](./events/students_imported_in_class.ex) event.

### Username Confirmation

Imported/created students start with an unconfirmed, auto-suggested username. A
student confirms or changes their own username with `configure_student/3`
([`ConfigureStudent`](./use_cases/configure_student.ex)), which sets
`username_confirmed: true` and emits a
[`StudentConfigured`](./events/student_configured.ex) event. The username is
validated (lowercase, starts with a letter, hyphens allowed, max 20 chars, the
reserved name `archidep` is rejected, unique within the class).

This is the only student-initiated write in the context; the UI is the
[`ChangeUsernameDialogLive`](../../archidep_web/course/change_username_dialog_live.ex)
component opened from the user's profile page.

---

## Expected Server Properties

Each class owns an
[`ExpectedServerProperties`](./schemas/expected_server_properties.ex) record
(`server_properties` table) describing the hardware and OS a student's cloud
server is **expected** to have: `hostname`, `machine_id`, CPU/core/vCPU counts,
`memory`, `swap`, `architecture`, `os_family`, `distribution` (and release /
version), etc. Every field is optional — a blank record means "no expectation".

Teachers set these per class with
`update_expected_server_properties_for_class/3`. The [Servers
context](../servers.ex) uses them to detect servers that deviate from what the
class expects (e.g. an oversized, costly VM, or the wrong OS).

---

## Course Material Integration

The [`Material`](./material.ex) module exposes the structure of the [course
material site](../../../../course/CONTRIBUTING.md#json-exports) —
`course_sections/0`, `course_cheatsheets/0`, and specific documents such as the
"run a virtual server" exercise and the sysadmin cheatsheet — so the dashboard
can render the same navigation and link to course content.

The data comes from `priv/static/archidep.json`, which the Jekyll build of the
`course` site writes into the application's static directory. Crucially,
[`MaterialHelpers`](./helpers/material_helpers.ex) reads and decodes that file
at **compile time** (into module attributes), so there is no runtime file I/O;
its `__mix_recompile__?/0` hook compares a SHA-256 digest so the module is
recompiled whenever `archidep.json` changes. As a result, the course material
must be built before (or be rebuilt to update) the application — consistent with
the [overall build][app-contributing].

---

## Use Cases

Each public operation of [`course.ex`](../course.ex) is implemented by a use
case module under [`use_cases/`](./use_cases). Most write operations have a
`validate_*` companion that returns a changeset for live form validation without
persisting. All class/student management requires a **root** user; the
exceptions are noted.

**Classes**

- [`CreateClass`](./use_cases/create_class.ex) — `create_class/2`: create a
  class.
- [`UpdateClass`](./use_cases/update_class.ex) — `update_class/3`: update a
  class.
- [`DeleteClass`](./use_cases/delete_class.ex) — `delete_class/2`: delete a
  class (fails if it has servers).
- [`ReadClasses`](./use_cases/read_classes.ex) — `list_classes/1`,
  `list_active_classes/1`, `fetch_class/2`.
- [`UpdateExpectedServerPropertiesForClass`](./use_cases/update_expected_server_properties_for_class.ex)
  — `update_expected_server_properties_for_class/3` (see [Expected Server
  Properties](#expected-server-properties)).

**Students**

- [`CreateStudent`](./use_cases/create_student.ex) — `create_student/3`: add a
  student to a class.
- [`ImportStudents`](./use_cases/import_students.ex) — `import_students/3`: bulk
  [import](#student-import).
- [`UpdateStudent`](./use_cases/update_student.ex) — `update_student/3`: update
  any student field.
- [`ConfigureStudent`](./use_cases/configure_student.ex) — `configure_student/3`:
  **student self-service** username confirmation (see [Username
  Confirmation](#username-confirmation)).
- [`DeleteStudent`](./use_cases/delete_student.ex) — `delete_student/2`.
- [`ReadStudents`](./use_cases/read_students.ex) — `list_students/2`,
  `fetch_student_in_class/3` (root), and `fetch_authenticated_student/1`
  (any authenticated user, to load their own record); plus the live-read-model
  helpers `subscribe_student/1` + `refresh_student/2` (a single student),
  `subscribe_class_students/1` + `refresh_class_students/4` (a class's student
  list), and `subscribe_student_detail/1` + `refresh_student_detail/2` (a
  student with its nested class, for the admin student detail page).

---

## Business Events

Following the application's [event-logging convention][bounded-contexts], every
significant action is persisted as a business event under [`events/`](./events).
Class events are written to the `course:classes:{id}` stream and student events
to the `course:students:{id}` stream.

- [`ClassCreated`](./events/class_created.ex),
  [`ClassUpdated`](./events/class_updated.ex),
  [`ClassDeleted`](./events/class_deleted.ex),
  [`ClassExpectedServerPropertiesUpdated`](./events/class_expected_server_properties_updated.ex)
- [`StudentCreated`](./events/student_created.ex),
  [`StudentUpdated`](./events/student_updated.ex),
  [`StudentDeleted`](./events/student_deleted.ex),
  [`StudentConfigured`](./events/student_configured.ex),
  [`StudentsImportedInClass`](./events/students_imported_in_class.ex)

---

## Authorization

The context's [`Policy`](./policy.ex) implements the application-wide
[`ArchiDep.Policy` behaviour][authorization] with a deliberately small rule set:

- **Root users** (teachers/administrators) may perform any action.
- Any authenticated user may `fetch_authenticated_student` (to load their own
  record).
- A **student** may only `configure_student` on their own linked student record.
- Everything else is denied.

There is no separate "teacher" role — teachers are simply root users.

---

## References

- [Application documentation][app-contributing] — overall architecture,
  [bounded context anatomy][bounded-contexts] and [authorization][authorization]
- [Course material site documentation](../../../../course/CONTRIBUTING.md) — the
  Jekyll site and its [JSON
  exports](../../../../course/CONTRIBUTING.md#json-exports) consumed by
  [`Material`](#course-material-integration)
- [Accounts context](../accounts/CONTRIBUTING.md) — shares the `classes` and
  `students` tables

[app-contributing]: ../../../CONTRIBUTING.md
[authorization]: ../../../CONTRIBUTING.md#authorization
[bounded-contexts]: ../../../CONTRIBUTING.md#bounded-contexts
