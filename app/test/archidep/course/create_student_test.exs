defmodule ArchiDep.Course.CreateStudentTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox

  import ArchiDep.Support.PubSubTestHelpers,
    only: [collect_broadcasts: 1, received_broadcasts: 1]

  alias ArchiDep.Clock
  alias ArchiDep.Course.Behaviour
  alias ArchiDep.Course.Context
  alias ArchiDep.Course.PubSub
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
  # `user_accounts`) is watched as an adjacent must-not-touch table: creating a
  # student must never create or mutate an account row (see `docs/testing.md`).
  @affected_tables [Student, StoredEvent, User]

  setup :verify_on_exit!

  setup do
    stub(Clock.Mock, :now, fn -> @now end)
    :ok
  end

  setup_all do
    %{
      create_student: protect({Context, :create_student, 3}, Behaviour),
      validate_student: protect({Context, :validate_student, 3}, Behaviour)
    }
  end

  # The three creation tests below follow the create-testing strategy documented
  # in `docs/testing.md`: a random one (let the factory fill as much as
  # possible), a minimal one (only the required fields, the single optional left
  # out) and a full one (every optional set).

  test "create a student in a class", %{create_student: create_student} do
    class = CourseFactory.insert(:class)
    broadcasts = subscribe_student_broadcasts(class.id)

    # Random fixtures: the factory generates a unique name/email/username and
    # otherwise-valid data, exercising field combinations no single pinned test
    # would.
    data = CourseFactory.build(:student_data)
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, student} = create_student.(auth, class.id, data)

    student
    |> assert_created_student(data, class)
    |> assert_student_created_event(auth, data, class)
    |> assert_persisted_student(student.ssh_exercise_password)

    assert_row_count_diff(previous_counts, %{Student => 1, StoredEvent => 1})

    assert_student_created_broadcast(broadcasts, student)
  end

  test "create a minimal student in a class", %{create_student: create_student} do
    class = CourseFactory.insert(:class)
    broadcasts = subscribe_student_broadcasts(class.id)

    # Built by hand so the minimal valid set is explicit and does not drift: the
    # required fields, with the only optional (`academic_class`) left out.
    data = %{
      name: "Minimal Student",
      email: "minimal@example.archidep.ch",
      academic_class: nil,
      username: "minimal",
      domain: "example.archidep.ch",
      active: false,
      servers_enabled: false
    }

    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, student} = create_student.(auth, class.id, data)

    student
    |> assert_created_student(data, class)
    |> assert_student_created_event(auth, data, class)
    |> assert_persisted_student(student.ssh_exercise_password)

    assert_row_count_diff(previous_counts, %{Student => 1, StoredEvent => 1})

    assert_student_created_broadcast(broadcasts, student)
  end

  test "create a full student in a class", %{create_student: create_student} do
    class = CourseFactory.insert(:class)
    broadcasts = subscribe_student_broadcasts(class.id)

    # Built by hand with every optional set and both flags on, so the test pins
    # that they are persisted and audited.
    data = %{
      name: "Full Student",
      email: "full@example.archidep.ch",
      academic_class: "INFO-3",
      username: "fullstudent",
      domain: "example.archidep.ch",
      active: true,
      servers_enabled: true
    }

    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, student} = create_student.(auth, class.id, data)

    student
    |> assert_created_student(data, class)
    |> assert_student_created_event(auth, data, class)
    |> assert_persisted_student(student.ssh_exercise_password)

    assert_row_count_diff(previous_counts, %{Student => 1, StoredEvent => 1})

    assert_student_created_broadcast(broadcasts, student)
  end

  test "a non-root user cannot create a student", %{create_student: create_student} do
    class = CourseFactory.insert(:class)
    broadcasts = subscribe_student_broadcasts(class.id)

    data = CourseFactory.build(:student_data)
    auth = Factory.build(:authentication, root: false)

    previous_counts = count_rows(@affected_tables)

    # The authorization failure is masked as `:class_not_found` so it does not
    # leak the existence of a class the caller may not see.
    assert create_student.(auth, class.id, data) == {:error, :class_not_found}

    assert_no_student_persisted(broadcasts, previous_counts)
  end

  test "a student cannot be created in a class that does not exist", %{
    create_student: create_student
  } do
    data = CourseFactory.build(:student_data)

    previous_counts = count_rows(@affected_tables)

    # A well-formed but unknown ID reports the class as missing.
    root = Factory.build(:authentication, root: true)
    assert create_student.(root, Ecto.UUID.generate(), data) == {:error, :class_not_found}

    # The missing class is reported before the authorization check, so even a
    # non-root caller gets :class_not_found.
    non_root = Factory.build(:authentication, root: false)
    assert create_student.(non_root, Ecto.UUID.generate(), data) == {:error, :class_not_found}

    # No class exists to broadcast on, and no stored event also implies no
    # broadcast (emitted only after the creation commits).
    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
  end

  test "a student cannot be created with invalid data", %{create_student: create_student} do
    class = CourseFactory.insert(:class)
    broadcasts = subscribe_student_broadcasts(class.id)

    data = CourseFactory.build(:student_data, name: "")
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:error, changeset} = create_student.(auth, class.id, data)
    assert errors_on(changeset) == %{name: ["can't be blank"]}

    assert_no_student_persisted(broadcasts, previous_counts)
  end

  test "two students in the same class cannot share an email", %{create_student: create_student} do
    class = CourseFactory.insert(:class)

    CourseFactory.insert(:student, class: class, email: "dup@example.archidep.ch")

    broadcasts = subscribe_student_broadcasts(class.id)

    # The uniqueness check is case-insensitive and scoped to the class.
    data = CourseFactory.build(:student_data, email: "DUP@example.archidep.ch")
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:error, changeset} = create_student.(auth, class.id, data)
    assert errors_on(changeset) == %{email: ["has already been taken"]}

    assert_no_student_persisted(broadcasts, previous_counts)
  end

  test "two students in the same class cannot share a username", %{
    create_student: create_student
  } do
    class = CourseFactory.insert(:class)
    CourseFactory.insert(:student, class: class, username: "taken")
    broadcasts = subscribe_student_broadcasts(class.id)

    # The uniqueness check is case-insensitive and scoped to the class.
    data = CourseFactory.build(:student_data, username: "TAKEN")
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:error, changeset} = create_student.(auth, class.id, data)
    assert errors_on(changeset) == %{username: ["has already been taken"]}

    assert_no_student_persisted(broadcasts, previous_counts)
  end

  test "validate valid student data without creating anything", %{
    validate_student: validate_student
  } do
    class = CourseFactory.insert(:class)
    broadcasts = subscribe_student_broadcasts(class.id)

    data = CourseFactory.build(:student_data)
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, %Changeset{} = changeset} = validate_student.(auth, class.id, data)
    assert errors_on(changeset) == %{}

    # Validation is side-effect free.
    assert_no_student_persisted(broadcasts, previous_counts)
  end

  test "validate surfaces validation errors without creating anything", %{
    validate_student: validate_student
  } do
    class = CourseFactory.insert(:class)
    broadcasts = subscribe_student_broadcasts(class.id)

    # One representative invalid value proves validation actually runs.
    data = CourseFactory.build(:student_data, name: "")
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, %Changeset{} = changeset} = validate_student.(auth, class.id, data)
    assert errors_on(changeset) == %{name: ["can't be blank"]}

    # Validation is side-effect free.
    assert_no_student_persisted(broadcasts, previous_counts)
  end

  test "validating student data for a class that does not exist returns an error", %{
    validate_student: validate_student
  } do
    data = CourseFactory.build(:student_data)
    auth = Factory.build(:authentication, root: true)

    assert validate_student.(auth, Ecto.UUID.generate(), data) == {:error, :class_not_found}

    # No class exists to broadcast on, and no stored event also implies no
    # broadcast (emitted only after a successful commit).
    assert_no_stored_events!()
  end

  test "a non-root user cannot validate student data", %{validate_student: validate_student} do
    class = CourseFactory.insert(:class)
    broadcasts = subscribe_student_broadcasts(class.id)

    data = CourseFactory.build(:student_data)
    auth = Factory.build(:authentication, root: false)

    # The authorization failure is masked as `:class_not_found`.
    assert validate_student.(auth, class.id, data) == {:error, :class_not_found}

    assert_no_stored_events!()
    refute_student_created_broadcast(broadcasts)
  end

  # Asserts the use case's return value exactly: the created student with every
  # field taken from the requested `data`, the class association loaded, the
  # defaults the use case applies (`username_confirmed: false`, no linked user),
  # the version at 1 and the timestamps stamped at the pinned instant. The
  # randomly generated `ssh_exercise_password` is captured from the return value
  # and held, so every other field is pinned exactly.
  defp assert_created_student(%Student{} = student, data, class) do
    assert %Student{id: id, ssh_exercise_password: ssh_exercise_password} = student

    assert student == %Student{
             __meta__: loaded(Student, "students"),
             id: id,
             name: data.name,
             email: data.email,
             academic_class: data.academic_class,
             username: data.username,
             username_confirmed: false,
             domain: data.domain,
             active: data.active,
             servers_enabled: data.servers_enabled,
             ssh_exercise_password: ssh_exercise_password,
             class: class,
             class_id: class.id,
             user: not_loaded(:user, Student),
             user_id: nil,
             version: 1,
             created_at: @now,
             updated_at: @now
           }

    student
  end

  defp assert_student_created_event(%Student{id: id, class_id: class_id}, auth, data, class) do
    assert [%StoredEvent{id: event_id} = created_event] = fetch_new_stored_events()

    assert created_event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "course:students:#{id}",
             version: 1,
             type: "archidep/course/student-created",
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
                 "id" => class_id,
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

    created_event
  end

  # Reconstructs the expected persisted row from the already-asserted audit
  # event (proving the event is a complete audit log), supplying by hand only
  # what the event deliberately omits: the generated `ssh_exercise_password`,
  # the defaults the use case applies (`username_confirmed: false`, no linked
  # user), and the version/timestamps a "created" event implies. The bare row is
  # loaded so the comparison pins the columns alone, independent of the use
  # case's return value.
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

  # Subscribes the single topic a student-created broadcast reaches — the
  # class-students topic — in its own collector, so its delivery is asserted on
  # its own rather than funnelled into one indistinguishable mailbox.
  defp subscribe_student_broadcasts(class_id) do
    %{class_students: collect_broadcasts(fn -> PubSub.subscribe_class_students(class_id) end)}
  end

  # Asserts the student-created message reached the class-students topic exactly
  # once, carrying the created student, and nothing else.
  defp assert_student_created_broadcast(broadcasts, %Student{} = student) do
    assert received_broadcasts(broadcasts.class_students) == [{:student_created, student}]
  end

  # Asserts the class-students topic carried no student-created broadcast.
  defp refute_student_created_broadcast(broadcasts) do
    assert received_broadcasts(broadcasts.class_students) == []
  end

  # Asserts no student was created: no row added anywhere, no event and no
  # broadcast on the class-students topic.
  defp assert_no_student_persisted(broadcasts, previous_counts) do
    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
    refute_student_created_broadcast(broadcasts)
  end
end
