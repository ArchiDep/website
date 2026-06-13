defmodule ArchiDep.Course.DeleteStudentTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox
  alias ArchiDep.Clock
  alias ArchiDep.Course.Behaviour
  alias ArchiDep.Course.Context
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Course.Schemas.User
  alias ArchiDep.Errors.UnauthorizedError
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Repo
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.Factory

  # Pinned instant returned by the injected clock for the duration of each test,
  # so that the deletion event's `occurred_at` can be asserted exactly (see
  # `docs/testing.md`).
  @now ~U[2024-03-15 10:30:00.000000Z]

  # An instant safely before `@now`, so the deletion is visibly stamped at
  # `@now` rather than at the fixture's own timestamps.
  @past ~U[2023-09-15 09:42:17.000000Z]

  # Every table this use case can affect. `User` (the course's read model over
  # `user_accounts`) is watched as an adjacent must-not-touch table: deleting a
  # student that has not logged in must not touch any account row (see
  # `docs/testing.md`).
  @affected_tables [Student, StoredEvent, User]

  setup :verify_on_exit!

  setup do
    stub(Clock.Mock, :now, fn -> @now end)
    :ok
  end

  setup_all do
    %{delete_student: protect({Context, :delete_student, 2}, Behaviour)}
  end

  # A delete has no input fields to vary, so unlike create/update it gets a
  # single happy-path test (see `docs/testing.md`). The student has no linked
  # user account: deleting a student that has already logged in is a separate,
  # currently unsupported case (the `user_accounts.student_id` foreign key
  # nilifies on delete, which violates the non-root account check constraint).

  test "delete a student", %{delete_student: delete_student} do
    inserted = CourseFactory.insert(:student, %{user: nil, user_id: nil, now: @past})

    # Read the student back the way the use case does, so the event/broadcast
    # assertions compare against the exact struct it operates on (the factory
    # struct loads associations differently).
    student = persisted_student(inserted.id)

    :ok = PubSub.subscribe_student(student.id)
    :ok = PubSub.subscribe_class_students(student.class_id)

    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert delete_student.(auth, student.id) == :ok

    student
    |> assert_student_deleted_event(auth)
    |> assert_student_gone()
    |> assert_student_deleted_broadcast()

    assert_row_count_diff(previous_counts, %{Student => -1, StoredEvent => 1})
  end

  test "a student that does not exist cannot be deleted", %{delete_student: delete_student} do
    previous_counts = count_rows(@affected_tables)

    root = Factory.build(:authentication, root: true)
    assert delete_student.(root, Ecto.UUID.generate()) == {:error, :student_not_found}

    # Not-found is reported before the authorization check, so a non-root caller
    # also gets :student_not_found rather than an authorization error.
    non_root = Factory.build(:authentication, root: false)
    assert delete_student.(non_root, Ecto.UUID.generate()) == {:error, :student_not_found}

    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
  end

  test "a non-root user cannot delete a student", %{delete_student: delete_student} do
    student =
      CourseFactory.insert(:student, %{user: nil, user_id: nil, now: @past})

    :ok = PubSub.subscribe_student(student.id)
    :ok = PubSub.subscribe_class_students(student.class_id)

    auth = Factory.build(:authentication, root: false)

    previous_counts = count_rows(@affected_tables)

    assert_raise UnauthorizedError, fn -> delete_student.(auth, student.id) end

    assert persisted_student(student.id).id == student.id
    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
    refute_student_deleted_broadcast(student.id)
  end

  # Asserts the single `StudentDeleted` event: the deleted student's identity in
  # its stream, at the student's current version (a delete does not bump it),
  # stamped at the pinned instant. The deletion event is intentionally minimal
  # (id, name, email, class), so it is asserted whole rather than used to
  # reconstruct a row (see `docs/testing.md`).
  defp assert_student_deleted_event(%Student{} = student, auth) do
    assert [%StoredEvent{id: event_id} = deleted_event] = fetch_new_stored_events()

    assert deleted_event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "course:students:#{student.id}",
             version: student.version,
             type: "archidep/course/student-deleted",
             data: %{
               "id" => student.id,
               "name" => student.name,
               "email" => student.email,
               "class" => %{
                 "id" => student.class_id,
                 "name" => student.class.name
               }
             },
             meta: %{},
             initiator: "accounts:user-accounts:#{auth.principal_id}",
             causation_id: event_id,
             correlation_id: event_id,
             occurred_at: @now,
             entity: nil
           }

    student
  end

  defp assert_student_gone(%Student{id: id} = student) do
    refute Repo.exists?(from s in Student, where: s.id == ^id)
    student
  end

  defp assert_student_deleted_broadcast(%Student{id: id} = student) do
    # The use case publishes to both the student-specific and the class-students
    # topics; pin the student ID since both are shared across async tests.
    assert_receive {:student_deleted, %Student{id: ^id} = student_specific}
    assert_receive {:student_deleted, %Student{id: ^id} = class_scoped}

    assert student_specific == student
    assert class_scoped == student

    refute_received {:student_deleted, %Student{id: ^id}}

    student
  end

  defp refute_student_deleted_broadcast(id) do
    refute_received {:student_deleted, %Student{id: ^id}}
  end

  defp persisted_student(id) do
    {:ok, student} = Student.fetch_student(id)
    student
  end
end
