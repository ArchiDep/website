defmodule ArchiDep.Course.ConfigureStudentTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox

  import ArchiDep.Support.PubSubTestHelpers,
    only: [collect_broadcasts: 1, received_broadcasts: 1]

  import ArchiDep.Support.CourseTestHelpers
  alias ArchiDep.Clock
  alias ArchiDep.Course.Behaviour
  alias ArchiDep.Course.Context
  alias ArchiDep.Course.Events.StudentConfigured
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Events.Store.EventReference
  alias ArchiDep.Course.Schemas.Student
  alias ArchiDep.Course.Schemas.User
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Repo
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.Factory

  # Pinned instant returned by the injected clock for the duration of each test.
  # `register_student/1` persists its fixtures further in the past, so that
  # configuring visibly moves their `updated_at` forward to this instant.
  @now ~U[2024-03-15 10:30:00.000000Z]

  # Every table this use case can affect. `User` (the course's read model over
  # `user_accounts`) is watched as an adjacent must-not-touch table: confirming
  # a username updates the student, never the account (see `docs/testing.md`).
  @affected_tables [Student, StoredEvent, User]

  setup :verify_on_exit!

  setup do
    stub(Clock.Mock, :now, fn -> @now end)
    :ok
  end

  setup_all do
    %{
      configure_student: protect({Context, :configure_student, 3}, Behaviour),
      validate_student_config: protect({Context, :validate_student_config, 3}, Behaviour)
    }
  end

  describe "configure_student/3" do
    test "a student confirms their own username", %{configure_student: configure_student} do
      {student, _account, auth} = register_student(username_confirmed: false)

      broadcasts = subscribe_student_broadcasts(student)

      data = %{username: "my-handle"}

      previous_counts = count_rows(@affected_tables)

      assert {:ok, configured} = configure_student.(auth, student.id, data)

      configured
      |> assert_configured_student(student, data)
      |> assert_student_configured_event(auth, data)
      |> assert_persisted_student(student)

      assert_row_count_diff(previous_counts, %{StoredEvent => 1})
      assert_student_updated_broadcast(broadcasts, configured)
    end

    test "a root user can configure any student's username", %{
      configure_student: configure_student
    } do
      {student, _account, _auth} = register_student(username_confirmed: false)
      {root_auth, _root_account} = register_root()

      broadcasts = subscribe_student_broadcasts(student)

      data = %{username: "by-root"}

      previous_counts = count_rows(@affected_tables)

      assert {:ok, configured} = configure_student.(root_auth, student.id, data)

      configured
      |> assert_configured_student(student, data)
      |> assert_student_configured_event(root_auth, data)
      |> assert_persisted_student(student)

      assert_row_count_diff(previous_counts, %{StoredEvent => 1})
      assert_student_updated_broadcast(broadcasts, configured)
    end

    # Impersonation fully swaps the principal: a root user impersonating a
    # non-root student is authorized as that student, never with root's
    # override. The only trace of impersonation is `impersonated_id`, which the
    # policy ignores — so the impersonator gains exactly the student's
    # self-service access and nothing more.
    test "a root user impersonating a student configures that student's own username", %{
      configure_student: configure_student
    } do
      {student, account, _auth} = register_student(username_confirmed: false)

      impersonating_auth =
        Factory.build(:authentication,
          principal_id: account.id,
          root: false,
          impersonated_id: account.id
        )

      broadcasts = subscribe_student_broadcasts(student)

      data = %{username: "as-the-student"}

      previous_counts = count_rows(@affected_tables)

      assert {:ok, configured} = configure_student.(impersonating_auth, student.id, data)

      configured
      |> assert_configured_student(student, data)
      |> assert_student_configured_event(impersonating_auth, data)
      |> assert_persisted_student(student)

      assert_row_count_diff(previous_counts, %{StoredEvent => 1})
      assert_student_updated_broadcast(broadcasts, configured)
    end

    test "a root user impersonating a student cannot configure another student", %{
      configure_student: configure_student
    } do
      {target, _target_account, _target_auth} = register_student(username_confirmed: false)
      {_impersonated, impersonated_account, _impersonated_auth} = register_student()

      impersonating_auth =
        Factory.build(:authentication,
          principal_id: impersonated_account.id,
          root: false,
          impersonated_id: impersonated_account.id
        )

      baseline = persisted_student(target.id)

      broadcasts = subscribe_student_broadcasts(target)

      previous_counts = count_rows(@affected_tables)

      assert configure_student.(impersonating_auth, target.id, %{username: "stolen"}) ==
               {:error, :student_not_found}

      assert_configure_had_no_effect(baseline, broadcasts, previous_counts)
    end

    # The masked-error branches below all collapse to `{:error,
    # :student_not_found}` so the use case never leaks whether a student exists
    # or who owns it. Each upstream condition is driven separately and asserted
    # to produce the same masked result (see `docs/testing.md`).

    test "a student cannot configure another student", %{configure_student: configure_student} do
      {target, _target_account, _target_auth} = register_student(username_confirmed: false)
      {_other, _other_account, other_auth} = register_student()

      baseline = persisted_student(target.id)

      broadcasts = subscribe_student_broadcasts(target)

      previous_counts = count_rows(@affected_tables)

      assert configure_student.(other_auth, target.id, %{username: "stolen"}) ==
               {:error, :student_not_found}

      assert_configure_had_no_effect(baseline, broadcasts, previous_counts)
    end

    test "an authenticated user without an account cannot configure a student", %{
      configure_student: configure_student
    } do
      {student, _account, _auth} = register_student(username_confirmed: false)
      baseline = persisted_student(student.id)

      broadcasts = subscribe_student_broadcasts(student)

      # A principal that matches no `user_accounts` row is reported as not-found
      # rather than leaking that the student exists.
      stranger = Factory.build(:authentication, root: false)

      previous_counts = count_rows(@affected_tables)

      assert configure_student.(stranger, student.id, %{username: "ghost"}) ==
               {:error, :student_not_found}

      assert_configure_had_no_effect(baseline, broadcasts, previous_counts)
    end

    test "configuring a student that does not exist returns not found", %{
      configure_student: configure_student
    } do
      {_student, _account, auth} = register_student()

      previous_counts = count_rows(@affected_tables)

      assert configure_student.(auth, Ecto.UUID.generate(), %{username: "nobody"}) ==
               {:error, :student_not_found}

      assert_no_row_count_diff(previous_counts)
      assert_no_stored_events!()
    end

    test "a student cannot confirm an invalid username", %{configure_student: configure_student} do
      {student, _account, auth} = register_student(username_confirmed: false)
      baseline = persisted_student(student.id)

      broadcasts = subscribe_student_broadcasts(student)

      previous_counts = count_rows(@affected_tables)

      # "archidep" is reserved.
      assert {:error, changeset} = configure_student.(auth, student.id, %{username: "archidep"})
      assert errors_on(changeset) == %{username: ["this username is reserved and cannot be used"]}

      assert_configure_had_no_effect(baseline, broadcasts, previous_counts)
    end

    test "a student cannot confirm a username already taken in the class", %{
      configure_student: configure_student
    } do
      {student, _account, auth} = register_student(username_confirmed: false)
      CourseFactory.insert(:student, class: student.class, username: "taken")
      baseline = persisted_student(student.id)

      broadcasts = subscribe_student_broadcasts(student)

      previous_counts = count_rows(@affected_tables)

      assert {:error, changeset} = configure_student.(auth, student.id, %{username: "taken"})
      assert errors_on(changeset) == %{username: ["has already been taken"]}

      assert_configure_had_no_effect(baseline, broadcasts, previous_counts)
    end
  end

  describe "validate_student_config/3" do
    test "validate a valid username without changing anything", %{
      validate_student_config: validate_student_config
    } do
      {student, _account, auth} = register_student(username_confirmed: false)
      baseline = persisted_student(student.id)

      broadcasts = subscribe_student_broadcasts(student)

      previous_counts = count_rows(@affected_tables)

      assert {:ok, %Changeset{} = changeset} =
               validate_student_config.(auth, student.id, %{username: "valid-name"})

      assert errors_on(changeset) == %{}

      assert_configure_had_no_effect(baseline, broadcasts, previous_counts)
    end

    test "validate surfaces username errors without changing anything", %{
      validate_student_config: validate_student_config
    } do
      {student, _account, auth} = register_student(username_confirmed: false)
      baseline = persisted_student(student.id)

      broadcasts = subscribe_student_broadcasts(student)

      previous_counts = count_rows(@affected_tables)

      assert {:ok, %Changeset{} = changeset} =
               validate_student_config.(auth, student.id, %{username: "archidep"})

      assert errors_on(changeset) == %{username: ["this username is reserved and cannot be used"]}

      assert_configure_had_no_effect(baseline, broadcasts, previous_counts)
    end

    test "a student cannot validate the configuration of another student", %{
      validate_student_config: validate_student_config
    } do
      {target, _target_account, _target_auth} = register_student()
      {_other, _other_account, other_auth} = register_student()

      baseline = persisted_student(target.id)

      broadcasts = subscribe_student_broadcasts(target)

      previous_counts = count_rows(@affected_tables)

      assert validate_student_config.(other_auth, target.id, %{username: "nope"}) ==
               {:error, :student_not_found}

      assert_configure_had_no_effect(baseline, broadcasts, previous_counts)
    end

    test "an authenticated user without an account cannot validate a student config", %{
      validate_student_config: validate_student_config
    } do
      {student, _account, _auth} = register_student(username_confirmed: false)
      baseline = persisted_student(student.id)

      broadcasts = subscribe_student_broadcasts(student)

      # A principal that matches no `user_accounts` row is reported as not-found
      # rather than leaking that the student exists.
      stranger = Factory.build(:authentication, root: false)

      previous_counts = count_rows(@affected_tables)

      assert validate_student_config.(stranger, student.id, %{username: "ghost"}) ==
               {:error, :student_not_found}

      assert_configure_had_no_effect(baseline, broadcasts, previous_counts)
    end

    test "validating a student that does not exist returns not found", %{
      validate_student_config: validate_student_config
    } do
      {_student, _account, auth} = register_student()

      previous_counts = count_rows(@affected_tables)

      assert validate_student_config.(auth, Ecto.UUID.generate(), %{username: "nobody"}) ==
               {:error, :student_not_found}

      assert_no_row_count_diff(previous_counts)
      assert_no_stored_events!()
    end
  end

  # Asserts the return value exactly: the original student with only `username`
  # overwritten and `username_confirmed` flipped to `true`, the version bumped
  # by one, `created_at` preserved and `updated_at` stamped at the pinned
  # instant. The class and user associations are held from the return value, so
  # every scalar is pinned.
  defp assert_configured_student(%Student{} = student, %Student{} = original, data) do
    assert student == %Student{
             __meta__: loaded(Student, "students"),
             id: original.id,
             name: original.name,
             email: original.email,
             academic_class: original.academic_class,
             username: data.username,
             username_confirmed: true,
             domain: original.domain,
             active: original.active,
             servers_enabled: original.servers_enabled,
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

  defp assert_student_configured_event(
         %Student{id: id, name: name, email: email, class: class, version: version},
         auth,
         data
       ) do
    assert [%StoredEvent{id: event_id} = configured_event] = fetch_new_stored_events()

    assert configured_event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "course:students:#{id}",
             version: version,
             type: "archidep/course/student-configured",
             data: %{
               "id" => id,
               "name" => name,
               "email" => email,
               "username" => data.username,
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

    configured_event
  end

  # Reconstructs the expected persisted row from the already-asserted audit
  # event for the fields it carries (`username`, and `username_confirmed: true`
  # implied by the event type), taking from the `original` baseline only what
  # configuring leaves untouched and the event omits. The bare row is loaded so
  # the comparison pins the columns alone, independent of the use case's return
  # value.
  defp assert_persisted_student(
         %StoredEvent{
           data: %{
             "id" => id,
             "name" => name,
             "email" => email,
             "username" => username,
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
             academic_class: original.academic_class,
             username: username,
             username_confirmed: true,
             domain: original.domain,
             active: original.active,
             servers_enabled: original.servers_enabled,
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

  defp persisted_student(id) do
    {:ok, student} = Student.fetch_student(id)
    student
  end

  # Subscribes the two topics a student-updated broadcast reaches — the
  # student's own topic and the class-students topic — each in its own
  # collector, so each topic's delivery is asserted on its own rather than
  # funnelled into one indistinguishable mailbox.
  defp subscribe_student_broadcasts(%Student{id: id, class_id: class_id}) do
    %{
      specific: collect_broadcasts(fn -> PubSub.subscribe_student(id) end),
      class: collect_broadcasts(fn -> PubSub.subscribe_class_students(class_id) end)
    }
  end

  # Asserts the student-updated message reached both topics the use case
  # publishes to — the student-specific one and the class-students one — each
  # carrying the configured-student event and its reference, and nothing else.
  # Every reference field is known up front — the version and `occurred_at` from
  # the configuration itself, and (this being a root event) the
  # causation/correlation IDs equal its own ID — so only that ID is read back
  # from the stored event.
  defp assert_student_updated_broadcast(broadcasts, %Student{} = student) do
    [%StoredEvent{id: id}] = fetch_new_stored_events()

    reference = %EventReference{
      id: id,
      causation_id: id,
      correlation_id: id,
      version: student.version,
      occurred_at: @now
    }

    message = {:student_updated, StudentConfigured.new(student), reference}
    assert received_broadcasts(broadcasts.specific) == [message]
    assert received_broadcasts(broadcasts.class) == [message]
  end

  defp refute_student_updated_broadcast(broadcasts) do
    assert received_broadcasts(broadcasts.specific) == []
    assert received_broadcasts(broadcasts.class) == []
  end

  defp assert_configure_had_no_effect(%Student{} = baseline, broadcasts, previous_counts) do
    assert persisted_student(baseline.id) == baseline
    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
    refute_student_updated_broadcast(broadcasts)
  end
end
