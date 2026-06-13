defmodule ArchiDep.Course.UpdateStudentTest do
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
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.Factory

  # Pinned instant returned by the injected clock for the duration of each test,
  # so that every timestamp produced by the use case can be asserted exactly
  # (see `docs/testing.md`).
  @now ~U[2024-03-15 10:30:00.000000Z]

  # An instant safely before `@now`, used to persist the student fixtures in the
  # past so that an update visibly moves their `updated_at` forward to `@now`.
  @past ~U[2023-09-15 09:42:17.000000Z]

  # Every table this use case can affect. `User` (the course's read model over
  # `user_accounts`) is watched as an adjacent must-not-touch table (see
  # `docs/testing.md`).
  @affected_tables [Student, StoredEvent, User]

  setup :verify_on_exit!

  setup do
    stub(Clock.Mock, :now, fn -> @now end)
    :ok
  end

  setup_all do
    %{
      update_student: protect({Context, :update_student, 3}, Behaviour),
      validate_existing_student: protect({Context, :validate_existing_student, 3}, Behaviour)
    }
  end

  # The three update tests below follow the update-testing strategy documented
  # in `docs/testing.md`: "update everything" (start from a minimal student and
  # set every field — the empty -> set direction for the only optional), "clear
  # the optional" (start from a full student and reset it — the set -> empty
  # direction), and a random one.

  test "update every field of a student", %{update_student: update_student} do
    class = CourseFactory.insert(:class)

    # Start from a minimal student (the optional `academic_class` empty, both
    # flags off, no linked user) persisted in the past.
    original =
      CourseFactory.insert(:student, %{
        class: class,
        class_id: class.id,
        name: "Before",
        email: "before@example.archidep.ch",
        academic_class: nil,
        username: "before",
        username_confirmed: false,
        domain: "before.example.archidep.ch",
        active: false,
        servers_enabled: false,
        user: nil,
        user_id: nil,
        now: @past
      })

    :ok = PubSub.subscribe_student(original.id)
    :ok = PubSub.subscribe_class_students(class.id)

    data = %{
      name: "After",
      email: "after@example.archidep.ch",
      academic_class: "INFO-3",
      username: "after",
      domain: "after.example.archidep.ch",
      active: true,
      servers_enabled: true
    }

    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, student} = update_student.(auth, original.id, data)

    student
    |> assert_updated_student(original, data)
    |> assert_student_updated_event(auth, data)
    |> assert_persisted_student(original)

    assert_row_count_diff(previous_counts, %{StoredEvent => 1})
    assert_student_updated_broadcast(student)
  end

  test "clear the optional field of a student", %{update_student: update_student} do
    class = CourseFactory.insert(:class)

    # Start from a fully-populated student so that clearing the optional
    # exercises the set -> empty direction and pins that the update overwrites
    # the previous value rather than retaining it.
    original =
      CourseFactory.insert(:student, %{
        class: class,
        class_id: class.id,
        name: "Before",
        email: "before@example.archidep.ch",
        academic_class: "INFO-1",
        username: "before",
        username_confirmed: false,
        domain: "before.example.archidep.ch",
        active: true,
        servers_enabled: true,
        user: nil,
        user_id: nil,
        now: @past
      })

    :ok = PubSub.subscribe_student(original.id)
    :ok = PubSub.subscribe_class_students(class.id)

    data = %{
      name: "After",
      email: "after@example.archidep.ch",
      academic_class: nil,
      username: "after",
      domain: "after.example.archidep.ch",
      active: false,
      servers_enabled: false
    }

    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, student} = update_student.(auth, original.id, data)

    student
    |> assert_updated_student(original, data)
    |> assert_student_updated_event(auth, data)
    |> assert_persisted_student(original)

    assert_row_count_diff(previous_counts, %{StoredEvent => 1})
    assert_student_updated_broadcast(student)
  end

  test "update a student with random data", %{update_student: update_student} do
    class = CourseFactory.insert(:class)

    original =
      CourseFactory.insert(:student, %{
        class: class,
        class_id: class.id,
        user: nil,
        user_id: nil,
        now: @past
      })

    :ok = PubSub.subscribe_student(original.id)
    :ok = PubSub.subscribe_class_students(class.id)

    data = CourseFactory.build(:student_data)
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, student} = update_student.(auth, original.id, data)

    student
    |> assert_updated_student(original, data)
    |> assert_student_updated_event(auth, data)
    |> assert_persisted_student(original)

    assert_row_count_diff(previous_counts, %{StoredEvent => 1})
    assert_student_updated_broadcast(student)
  end

  test "a student can be updated while keeping its own email and username", %{
    update_student: update_student
  } do
    class = CourseFactory.insert(:class)

    # The uniqueness checks exclude the student being updated, so re-saving it
    # with its own email and username succeeds.
    original =
      CourseFactory.insert(:student, %{
        class: class,
        class_id: class.id,
        email: "keep@example.archidep.ch",
        username: "keep",
        user: nil,
        user_id: nil,
        now: @past
      })

    :ok = PubSub.subscribe_student(original.id)
    :ok = PubSub.subscribe_class_students(class.id)

    data =
      CourseFactory.build(:student_data, email: "keep@example.archidep.ch", username: "keep")

    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, student} = update_student.(auth, original.id, data)

    student
    |> assert_updated_student(original, data)
    |> assert_student_updated_event(auth, data)
    |> assert_persisted_student(original)

    assert_row_count_diff(previous_counts, %{StoredEvent => 1})
    assert_student_updated_broadcast(student)
  end

  test "a non-root user cannot update a student", %{update_student: update_student} do
    original = CourseFactory.insert(:student, unlinked_student_attrs(now: @past))
    baseline = persisted_student(original.id)

    :ok = PubSub.subscribe_student(original.id)
    :ok = PubSub.subscribe_class_students(original.class_id)

    data = CourseFactory.build(:student_data)
    auth = Factory.build(:authentication, root: false)

    previous_counts = count_rows(@affected_tables)

    assert_raise UnauthorizedError, fn -> update_student.(auth, original.id, data) end

    assert_update_had_no_effect(baseline, previous_counts)
  end

  test "a student that does not exist cannot be updated", %{update_student: update_student} do
    data = CourseFactory.build(:student_data)

    previous_counts = count_rows(@affected_tables)

    root = Factory.build(:authentication, root: true)
    assert update_student.(root, Ecto.UUID.generate(), data) == {:error, :student_not_found}

    # The missing student is reported before the authorization check.
    non_root = Factory.build(:authentication, root: false)

    assert update_student.(non_root, Ecto.UUID.generate(), data) ==
             {:error, :student_not_found}

    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
  end

  test "a student cannot be updated with invalid data", %{update_student: update_student} do
    original = CourseFactory.insert(:student, unlinked_student_attrs(now: @past))
    baseline = persisted_student(original.id)

    :ok = PubSub.subscribe_student(original.id)
    :ok = PubSub.subscribe_class_students(original.class_id)

    data = CourseFactory.build(:student_data, name: "")
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:error, changeset} = update_student.(auth, original.id, data)
    assert errors_on(changeset) == %{name: ["can't be blank"]}

    assert_update_had_no_effect(baseline, previous_counts)
  end

  test "a student cannot take an email already used in the same class", %{
    update_student: update_student
  } do
    class = CourseFactory.insert(:class)
    CourseFactory.insert(:student, class: class, email: "taken@example.archidep.ch")

    original =
      CourseFactory.insert(:student, %{
        class: class,
        class_id: class.id,
        user: nil,
        user_id: nil,
        now: @past
      })

    baseline = persisted_student(original.id)

    :ok = PubSub.subscribe_student(original.id)
    :ok = PubSub.subscribe_class_students(class.id)

    # The uniqueness check is case-insensitive.
    data = CourseFactory.build(:student_data, email: "TAKEN@example.archidep.ch")
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:error, changeset} = update_student.(auth, original.id, data)
    assert errors_on(changeset) == %{email: ["has already been taken"]}

    assert_update_had_no_effect(baseline, previous_counts)
  end

  test "a student cannot take a username already used in the same class", %{
    update_student: update_student
  } do
    class = CourseFactory.insert(:class)
    CourseFactory.insert(:student, class: class, username: "taken")

    original =
      CourseFactory.insert(:student, %{
        class: class,
        class_id: class.id,
        user: nil,
        user_id: nil,
        now: @past
      })

    baseline = persisted_student(original.id)

    :ok = PubSub.subscribe_student(original.id)
    :ok = PubSub.subscribe_class_students(class.id)

    # The uniqueness check is case-insensitive.
    data = CourseFactory.build(:student_data, username: "TAKEN")
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:error, changeset} = update_student.(auth, original.id, data)
    assert errors_on(changeset) == %{username: ["has already been taken"]}

    assert_update_had_no_effect(baseline, previous_counts)
  end

  test "validate valid update data for an existing student without changing anything", %{
    validate_existing_student: validate_existing_student
  } do
    original = CourseFactory.insert(:student, unlinked_student_attrs(now: @past))
    baseline = persisted_student(original.id)

    :ok = PubSub.subscribe_student(original.id)
    :ok = PubSub.subscribe_class_students(original.class_id)

    data = CourseFactory.build(:student_data)
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, %Changeset{} = changeset} =
             validate_existing_student.(auth, original.id, data)

    assert errors_on(changeset) == %{}

    # Validation is side-effect free.
    assert_update_had_no_effect(baseline, previous_counts)
  end

  test "validate surfaces validation errors for an existing student without changing anything",
       %{validate_existing_student: validate_existing_student} do
    original = CourseFactory.insert(:student, unlinked_student_attrs(now: @past))
    baseline = persisted_student(original.id)

    :ok = PubSub.subscribe_student(original.id)
    :ok = PubSub.subscribe_class_students(original.class_id)

    data = CourseFactory.build(:student_data, name: "")
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, %Changeset{} = changeset} =
             validate_existing_student.(auth, original.id, data)

    assert errors_on(changeset) == %{name: ["can't be blank"]}

    # Validation is side-effect free.
    assert_update_had_no_effect(baseline, previous_counts)
  end

  test "validating update data for a student that does not exist returns an error", %{
    validate_existing_student: validate_existing_student
  } do
    data = CourseFactory.build(:student_data)
    auth = Factory.build(:authentication, root: true)

    assert validate_existing_student.(auth, Ecto.UUID.generate(), data) ==
             {:error, :student_not_found}

    assert_no_stored_events!()
  end

  test "a non-root user cannot validate update data for a student", %{
    validate_existing_student: validate_existing_student
  } do
    original = CourseFactory.insert(:student, unlinked_student_attrs(now: @past))
    baseline = persisted_student(original.id)

    data = CourseFactory.build(:student_data)
    auth = Factory.build(:authentication, root: false)

    previous_counts = count_rows(@affected_tables)

    assert_raise UnauthorizedError, fn ->
      validate_existing_student.(auth, original.id, data)
    end

    assert_update_had_no_effect(baseline, previous_counts)
  end

  # Standard attributes for a student with no linked user account, so its
  # associations are deterministic regardless of the factory's random optional
  # user.
  defp unlinked_student_attrs(extra),
    do: Map.merge(%{user: nil, user_id: nil}, Map.new(extra))

  # Asserts the use case's return value exactly: the original student with every
  # field overwritten by `data`, `username_confirmed`/`ssh_exercise_password`
  # and the linked-user association left untouched, the version bumped by one,
  # `created_at` preserved and `updated_at` stamped at the pinned instant. The
  # class and user associations are taken from the return value (the use case
  # reloads them) and held, so every scalar is pinned exactly.
  defp assert_updated_student(%Student{} = student, %Student{} = original, data) do
    assert student == %Student{
             __meta__: loaded(Student, "students"),
             id: original.id,
             name: data.name,
             email: data.email,
             academic_class: data.academic_class,
             username: data.username,
             username_confirmed: original.username_confirmed,
             domain: data.domain,
             active: data.active,
             servers_enabled: data.servers_enabled,
             ssh_exercise_password: original.ssh_exercise_password,
             class: student.class,
             class_id: original.class_id,
             user: student.user,
             user_id: original.user_id,
             version: original.version + 1,
             created_at: original.created_at,
             updated_at: @now
           }

    student
  end

  defp assert_student_updated_event(%Student{id: id, class: class, version: version}, auth, data) do
    assert [%StoredEvent{id: event_id} = updated_event] = fetch_new_stored_events()

    assert updated_event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "course:students:#{id}",
             version: version,
             type: "archidep/course/student-updated",
             data: %{
               "id" => id,
               "name" => data.name,
               "email" => data.email,
               "academic_class" => data.academic_class,
               "username" => data.username,
               "domain" => data.domain,
               "active" => data.active,
               "servers_enabled" => data.servers_enabled,
               "class" => %{
                 "id" => class.id,
                 "name" => class.name
               }
             },
             meta: %{},
             initiator: "accounts:user-accounts:#{auth.principal_id}",
             causation_id: event_id,
             correlation_id: event_id,
             occurred_at: @now,
             entity: nil
           }

    updated_event
  end

  # Reconstructs the expected persisted row from the already-asserted audit
  # event for every field it carries (and the bumped version/`occurred_at` it
  # implies), taking from the `original` baseline only what an update leaves
  # untouched and the event omits: `username_confirmed`, the generated
  # `ssh_exercise_password`, the linked-user foreign key and `created_at`. The
  # bare row is loaded so the comparison pins the columns alone, independent of
  # the use case's return value.
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
           version: version,
           occurred_at: now
         },
         %Student{} = original
       ) do
    assert Repo.get!(Student, id) == %Student{
             __meta__: loaded(Student, "students"),
             id: id,
             name: name,
             email: email,
             academic_class: academic_class,
             username: username,
             username_confirmed: original.username_confirmed,
             domain: domain,
             active: active,
             servers_enabled: servers_enabled,
             ssh_exercise_password: original.ssh_exercise_password,
             class: not_loaded(:class, Student),
             class_id: class_id,
             user: not_loaded(:user, Student),
             user_id: original.user_id,
             version: version,
             created_at: original.created_at,
             updated_at: now
           }
  end

  defp assert_student_updated_broadcast(%Student{id: id} = student) do
    # The use case publishes to both the student-specific and the class-students
    # topics; pin the student ID since both are shared across async tests.
    assert_receive {:student_updated, %Student{id: ^id} = student_specific}
    assert_receive {:student_updated, %Student{id: ^id} = class_scoped}

    assert student_specific == student
    assert class_scoped == student

    refute_received {:student_updated, %Student{id: ^id}}
  end

  defp refute_student_updated_broadcast(id) do
    refute_received {:student_updated, %Student{id: ^id}}
  end

  # Reads the student back the way the use case does, for capturing a baseline
  # before a rejected call and asserting the row is unchanged after it.
  defp persisted_student(id) do
    {:ok, student} = Student.fetch_student(id)
    student
  end

  # Asserts a rejected update left no trace: the student row is unchanged, no
  # rows were added or removed anywhere, and no event or broadcast was emitted.
  defp assert_update_had_no_effect(%Student{} = baseline, previous_counts) do
    assert persisted_student(baseline.id) == baseline
    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
    refute_student_updated_broadcast(baseline.id)
  end
end
