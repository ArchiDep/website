# Known issues

This document records known bugs and limitations in the dashboard application
that have been identified but deliberately **deferred** — each is something to
come back to and decide what to do about, rather than a task already scheduled
in a plan. Add a level-2 heading per issue, describing the symptom, the cause,
and the options for resolving it.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Deleting a student who has logged in fails](#deleting-a-student-who-has-logged-in-fails)

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
