defmodule ArchiDep.Course.ImportStudentsTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox

  import ArchiDep.Support.PubSubTestHelpers,
    only: [collect_broadcasts: 1, received_broadcasts: 1]

  alias ArchiDep.Clock
  alias ArchiDep.Course.Behaviour
  alias ArchiDep.Course.Context
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Course.Schemas.User
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Repo
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.Factory

  # Pinned instant returned by the injected clock for the duration of each test,
  # so that every timestamp produced by the use case can be asserted exactly
  # (see `docs/testing.md`).
  @now ~U[2024-03-15 10:30:00.000000Z]

  # Every table this use case can affect. `User` (the course's read model over
  # `user_accounts`) is watched as an adjacent must-not-touch table: importing
  # students must never create or mutate an account row (see `docs/testing.md`).
  @affected_tables [Student, StoredEvent, User]

  setup :verify_on_exit!

  setup do
    stub(Clock.Mock, :now, fn -> @now end)
    :ok
  end

  setup_all do
    # Student import has no `validate_*` companion (unlike `create_student`), so
    # only the committing use case is contract-checked.
    %{import_students: protect({Context, :import_students, 3}, Behaviour)}
  end

  # Student import is a *bulk* create with no single-record equivalent: one call
  # returns a list of students, emits one `StudentsImportedInClass` event plus
  # one `StudentCreated` event per new student, and generates a username and SSH
  # password for each. A few assertions therefore depart from the usual
  # create-testing canon; the departures are flagged inline.

  test "import several students into a class", %{import_students: import_students} do
    class = CourseFactory.insert(:class)
    class_students = subscribe_class_students(class)

    # Controlled emails so the generated usernames are deterministic (the
    # generation algorithm itself is exhaustively pinned in
    # `schemas/student_import_list_test.exs`).
    data = %{
      academic_class: "BIO-1",
      domain: "example.ch",
      students: [
        %{name: "John Doe", email: "john.doe@example.ch"},
        %{name: "Jane Smith", email: "jane.smith@example.ch"}
      ]
    }

    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, students} = import_students.(auth, class.id, data)

    students
    |> assert_imported_students(class, data.students, data)
    |> assert_import_events(class, auth, data, 2)
    |> assert_persisted_students()

    # One generated username pinned to an exact literal to anchor the wiring;
    # the rest are bound and cross-referenced into the events and rows above (a
    # value produced by the separately and exhaustively tested
    # `to_insert_data/4` is not re-pinned here, which would duplicate that test
    # and let it rot — the same reasoning the canon gives for not re-testing
    # schema rules in use-case tests).
    assert student_by_email(students, "john.doe@example.ch").username == "jde"

    assert_row_count_diff(previous_counts, %{Student => 2, StoredEvent => 3})

    assert_students_imported_broadcast(class_students, class, students)
  end

  test "import a single student with no academic class", %{import_students: import_students} do
    class = CourseFactory.insert(:class)
    class_students = subscribe_class_students(class)

    # Minimal payload: the optional academic class left out (nil), a single
    # student.
    data = %{
      academic_class: nil,
      domain: "example.ch",
      students: [%{name: "John Doe", email: "john.doe@example.ch"}]
    }

    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, students} = import_students.(auth, class.id, data)

    students
    |> assert_imported_students(class, data.students, data)
    |> assert_import_events(class, auth, data, 1)
    |> assert_persisted_students()

    assert_row_count_diff(previous_counts, %{Student => 1, StoredEvent => 2})

    assert_students_imported_broadcast(class_students, class, students)
  end

  test "students already in the class are skipped", %{import_students: import_students} do
    class = CourseFactory.insert(:class)

    # A student already in the class. Inserted directly (not through the use
    # case), so it produces no events and the count snapshot below already
    # includes it.
    CourseFactory.insert(:student, class: class, email: "existing@example.ch")

    class_students = subscribe_class_students(class)

    # The import re-includes the existing email plus a new student. The conflict
    # is silently skipped (`on_conflict: :nothing` on `[:class_id, :email]`) —
    # unlike `create_student`, which rejects a duplicate email outright.
    data = %{
      academic_class: "BIO-1",
      domain: "example.ch",
      students: [
        %{name: "Existing Student", email: "existing@example.ch"},
        %{name: "Jane Smith", email: "jane.smith@example.ch"}
      ]
    }

    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, students} = import_students.(auth, class.id, data)

    # Only the new student is imported, audited and broadcast; the import event
    # counts only the new student.
    assert [%Student{email: "jane.smith@example.ch"}] = students

    students
    |> assert_imported_students(
      class,
      [%{name: "Jane Smith", email: "jane.smith@example.ch"}],
      data
    )
    |> assert_import_events(class, auth, data, 1)
    |> assert_persisted_students()

    assert_row_count_diff(previous_counts, %{Student => 1, StoredEvent => 2})

    assert_students_imported_broadcast(class_students, class, students)
  end

  test "importing only students that already exist is a no-op", %{
    import_students: import_students
  } do
    class = CourseFactory.insert(:class)
    CourseFactory.insert(:student, class: class, email: "existing@example.ch")
    class_students = subscribe_class_students(class)

    data = %{
      academic_class: "BIO-1",
      domain: "example.ch",
      students: [%{name: "Existing Student", email: "existing@example.ch"}]
    }

    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, []} = import_students.(auth, class.id, data)

    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()

    # Nothing was inserted, so the use case skips the broadcast: no notification
    # is published.
    assert received_broadcasts(class_students) == []
  end

  test "students cannot be imported with invalid data", %{import_students: import_students} do
    class = CourseFactory.insert(:class)
    class_students = subscribe_class_students(class)

    # One representative invalid value proves validation runs and rolls back;
    # the exhaustive validation coverage lives in the schema test.
    data = %{
      academic_class: "BIO-1",
      domain: "not a domain",
      students: [%{name: "John Doe", email: "john.doe@example.ch"}]
    }

    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:error, changeset} = import_students.(auth, class.id, data)

    assert errors_on(changeset) == %{
             domain: [
               "must be a valid domain name containing only letters (without accents), numbers and hyphens"
             ]
           }

    assert_no_students_imported(class_students, previous_counts)
  end

  test "students cannot be imported into a class that does not exist", %{
    import_students: import_students
  } do
    data = %{
      academic_class: "BIO-1",
      domain: "example.ch",
      students: [%{name: "John Doe", email: "john.doe@example.ch"}]
    }

    previous_counts = count_rows(@affected_tables)

    # A well-formed but unknown ID reports the class as missing.
    root = Factory.build(:authentication, root: true)
    assert import_students.(root, Ecto.UUID.generate(), data) == {:error, :class_not_found}

    # The missing class is reported before the authorization check, so even a
    # non-root caller gets :class_not_found.
    non_root = Factory.build(:authentication, root: false)
    assert import_students.(non_root, Ecto.UUID.generate(), data) == {:error, :class_not_found}

    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
  end

  test "a non-root user cannot import students", %{import_students: import_students} do
    class = CourseFactory.insert(:class)
    class_students = subscribe_class_students(class)

    data = %{
      academic_class: "BIO-1",
      domain: "example.ch",
      students: [%{name: "John Doe", email: "john.doe@example.ch"}]
    }

    auth = Factory.build(:authentication, root: false)

    previous_counts = count_rows(@affected_tables)

    # The authorization failure is masked as `:class_not_found` so it does not
    # leak the existence of a class the caller may not see, consistent with the
    # other course use cases.
    assert import_students.(auth, class.id, data) == {:error, :class_not_found}

    assert_no_students_imported(class_students, previous_counts)
  end

  # Asserts the use case's return value: the list of imported students, each
  # pinned exactly. The list order is not guaranteed (`insert_all … returning:
  # true` returns rows in no particular order), so actual and expected are
  # matched by email. The generated id, username and SSH password cannot be
  # pinned, so they are bound per student and every other field is asserted by
  # equality.
  defp assert_imported_students(students, class, expected_students, data) do
    actual = Enum.sort_by(students, & &1.email)
    expected = Enum.sort_by(expected_students, & &1.email)

    assert length(actual) == length(expected)

    actual
    |> Enum.zip(expected)
    |> Enum.each(fn {student, expected} ->
      assert %Student{id: id, username: username, ssh_exercise_password: password} = student

      assert student == %Student{
               __meta__: loaded(Student, "students"),
               id: id,
               name: expected.name,
               email: expected.email,
               academic_class: data.academic_class,
               username: username,
               username_confirmed: false,
               domain: data.domain,
               active: true,
               servers_enabled: false,
               ssh_exercise_password: password,
               class: class,
               class_id: class.id,
               user: not_loaded(:user, Student),
               user_id: nil,
               version: 1,
               created_at: @now,
               updated_at: @now
             }
    end)

    students
  end

  # Asserts the whole audit trail: exactly one `StudentsImportedInClass` event
  # for the class plus one `StudentCreated` event per imported student, and the
  # causation chain linking each student event to the import event. All events
  # share `occurred_at == @now`, so they cannot be matched by their position in
  # `fetch_new_stored_events/0`; the import event is found by type and each
  # student event by its student ID. Returns the student events keyed by ID so
  # the persisted rows can be reconstructed from them.
  defp assert_import_events(students, class, auth, data, expected_count) do
    events = fetch_new_stored_events()
    assert length(events) == expected_count + 1

    import_event = assert_students_imported_event(events, class, auth, data, expected_count)

    student_events =
      for student <- students,
          into: %{},
          do:
            {student.id, assert_student_created_event(events, student, class, auth, import_event)}

    {students, student_events}
  end

  defp assert_students_imported_event(events, class, auth, data, expected_count) do
    assert [%StoredEvent{id: event_id} = import_event] =
             Enum.filter(events, &(&1.type == "archidep/course/students-imported-in-class"))

    assert import_event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "course:classes:#{class.id}",
             # The import event is added to the class stream at the class's
             # current version (the import does not mutate the class).
             version: class.version,
             schema_version: 1,
             type: "archidep/course/students-imported-in-class",
             data: %{
               "class_id" => class.id,
               "class_name" => class.name,
               "academic_class" => data.academic_class,
               "domain" => data.domain,
               "number_of_students" => expected_count
             },
             meta: %{},
             initiator: "accounts:user-accounts:#{auth.principal_id}",
             causation_id: event_id,
             correlation_id: event_id,
             occurred_at: @now,
             entity: nil
           }

    import_event
  end

  defp assert_student_created_event(events, %Student{id: id} = student, class, auth, import_event) do
    assert [%StoredEvent{} = created_event] =
             Enum.filter(
               events,
               &(&1.type == "archidep/course/student-created" and &1.data["id"] == id)
             )

    assert created_event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: created_event.id,
             stream: "course:students:#{id}",
             version: 1,
             schema_version: 1,
             type: "archidep/course/student-created",
             data: %{
               "id" => id,
               "name" => student.name,
               "email" => student.email,
               "academic_class" => student.academic_class,
               "username" => student.username,
               "domain" => student.domain,
               "active" => true,
               "servers_enabled" => false,
               "class" => %{
                 "id" => class.id,
                 "name" => class.name
               }
             },
             meta: %{},
             initiator: "accounts:user-accounts:#{auth.principal_id}",
             # Each student creation is caused by the single import event, which
             # is itself the root of the chain.
             causation_id: import_event.id,
             correlation_id: import_event.id,
             occurred_at: @now,
             entity: nil
           }

    created_event
  end

  # Reconstructs each persisted row from its already-asserted `StudentCreated`
  # event (proving the event is a complete audit log), supplying by hand only
  # what the event omits: the generated `ssh_exercise_password` (taken from the
  # returned student), the use-case defaults (`username_confirmed: false`, no
  # linked user) and the version/timestamps a creation implies.
  defp assert_persisted_students({students, student_events}) do
    passwords = Map.new(students, &{&1.id, &1.ssh_exercise_password})

    for {id, event} <- student_events do
      assert_persisted_student(event, Map.fetch!(passwords, id))
    end

    {students, student_events}
  end

  defp assert_persisted_student(
         %StoredEvent{
           data: %{
             "id" => id,
             "name" => name,
             "email" => email,
             "academic_class" => academic_class,
             "username" => username,
             "domain" => domain,
             "active" => active,
             "servers_enabled" => servers_enabled,
             "class" => %{"id" => class_id}
           },
           occurred_at: now
         },
         ssh_exercise_password
       ) do
    assert Repo.get!(Student, id) == %Student{
             __meta__: loaded(Student, "students"),
             id: id,
             name: name,
             email: email,
             academic_class: academic_class,
             username: username,
             username_confirmed: false,
             domain: domain,
             active: active,
             servers_enabled: servers_enabled,
             ssh_exercise_password: ssh_exercise_password,
             class: not_loaded(:class, Student),
             class_id: class_id,
             user: not_loaded(:user, Student),
             user_id: nil,
             version: 1,
             created_at: now,
             updated_at: now
           }
  end

  # Subscribes the class-students topic — the single topic a students-imported
  # broadcast reaches — in its own collector, so its delivery is asserted on its
  # own rather than funnelled into one indistinguishable mailbox.
  defp subscribe_class_students(%Class{id: class_id}),
    do: collect_broadcasts(fn -> PubSub.subscribe_class_students(class_id) end)

  # Asserts the students-imported message reached the class-students topic
  # carrying the class and the exact list of imported students, and nothing
  # else.
  defp assert_students_imported_broadcast(class_students, %Class{} = class, students) do
    assert received_broadcasts(class_students) == [{:students_imported, class, students}]
  end

  # Asserts no student was imported: no row added anywhere, no event, and the
  # class-students topic stayed silent.
  defp assert_no_students_imported(class_students, previous_counts) do
    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
    assert received_broadcasts(class_students) == []
  end

  defp student_by_email(students, email), do: Enum.find(students, &(&1.email == email))
end
