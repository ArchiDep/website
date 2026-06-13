# Known issues

This document records known bugs and limitations in the dashboard application
that have been identified but deliberately **deferred** — each is something to
come back to and decide what to do about, rather than a task already scheduled
in a plan. Add a level-2 heading per issue, describing the symptom, the cause,
and the options for resolving it.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Deleting a student who has logged in fails](#deleting-a-student-who-has-logged-in-fails)
- [SSH host key fingerprint parsing crashes on malformed input](#ssh-host-key-fingerprint-parsing-crashes-on-malformed-input)

<!-- END doctoc -->

## Deleting a student who has logged in fails

`ArchiDep.Course.UseCases.DeleteStudent.delete_student/2` deletes the `students`
row directly. Once a student has logged in for the first time, the accounts
context links a `user_accounts` row to them: the account's `student_id` column
points at the student, and the student's `user_account_id` points back at the
account.

Deleting such a student fails at the database level. The
`user_accounts.student_id` foreign key is `ON DELETE SET NULL` (migration
`20250622155746_link_user_accounts_to_students_and_add_active_flags`), so
deleting the student nilifies the account's `student_id`. But a check constraint
requires every non-root account to keep a `student_id` (`root <> (student_id IS
NOT NULL)`, migration `20250914160945_add_root_vs_student_check_constraint`), so
the nilification violates it and the whole transaction is rolled back with a
constraint error that the use case does not handle gracefully.

In practice this means a student can only be deleted **before** they have ever
logged in. The use case also carries a `# TODO: shut down server` comment,
suggesting the full deletion story (what happens to the account, sessions and
any provisioned server) is not yet designed.

Decision to make: either **block** the deletion explicitly with a clear domain
error when the student has a linked account (and document that the account must
be removed first), or **support** it by tearing down the linked account (and its
sessions/servers) as part of the same transaction.

Coverage note: `delete_student_test.exs` therefore covers only the unlinked
case; the linked case has no test pending this decision.

## SSH host key fingerprint parsing crashes on malformed input

`ArchiDep.Servers.SSH.SSHKeyFingerprint.parse/2` raises a `WithClauseError` on a
fingerprint line that matches no known fingerprint format at all. The `:md5` and
`:sha256` clauses use a `with` whose `else` only handles the `{:ok,
fingerprint_string, key_alg, raw}` fallthrough (a well-formed line whose digest
is the wrong type or otherwise invalid). When `parse_ssh_keygen_output_line/1`
instead returns `{:error, :malformed}` — i.e. the line does not match the regex
— no `else` clause matches and the function crashes.

This is reachable from the course layer: `Class`'s `validate/1` calls
`SSH.parse_ssh_host_key_fingerprints/2` on the
`ssh_exercise_vm_md5_host_key_fingerprints` /
`ssh_exercise_vm_sha256_host_key_fingerprints` fields, expecting a graceful
`{:error, reason}`. A teacher who pastes arbitrary text into either field of the
class form therefore crashes the changeset validation (and the LiveView) instead
of seeing the intended "must contain at least one valid SSH host key
fingerprint…" error.

Decision to make: make `parse/2` (or `parse_ssh_keygen_output_line/1`) return
`{:error, :malformed}` through the `with` rather than raising, so the schema
surfaces it as a normal validation error.

Coverage note: `class_test.exs` currently exercises the invalid-fingerprint path
with a well-formed _wrong-digest_ fingerprint (which the parser handles
gracefully), deliberately sidestepping this crash. Once the parser is fixed, add
a case that feeds genuinely malformed text (e.g. `"not-a-fingerprint"`) to both
fingerprint fields and asserts the expected validation error.
