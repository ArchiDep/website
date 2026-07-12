defmodule ArchiDep.Course.CreateClassTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox

  import ArchiDep.Support.PubSubTestHelpers,
    only: [collect_broadcasts: 1, received_broadcasts: 1]

  alias ArchiDep.Clock
  alias ArchiDep.Course.Behaviour
  alias ArchiDep.Course.Context
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.ExpectedServerProperties
  alias ArchiDep.Errors.UnauthorizedError
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Repo
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.Factory
  alias ArchiDep.Support.SSHFactory

  # Pinned instant returned by the injected clock for the duration of each test,
  # so that every timestamp produced by the use case can be asserted exactly
  # (see `docs/testing.md`).
  @now ~U[2024-03-15 10:30:00.000000Z]

  @teacher_ssh_public_key "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC3randomkey== teacher@host"

  # Every table this use case can affect. Snapshot all of them with
  # `count_rows/1` before each call so the row-count diff catches a stray write
  # to any of them, not just the ones a given test happens to think about (see
  # `docs/testing.md`).
  @affected_tables [Class, ExpectedServerProperties, StoredEvent]

  setup :verify_on_exit!

  setup do
    stub(Clock.Mock, :now, fn -> @now end)
    :ok
  end

  setup_all do
    %{
      create_class: protect({Context, :create_class, 2}, Behaviour),
      validate_class: protect({Context, :validate_class, 2}, Behaviour)
    }
  end

  # The three creation tests below follow the create-testing strategy documented
  # in `docs/testing.md`: a random one (let the factory fill as much as
  # possible), a minimal one (only the required fields, every optional left
  # out), and a full one (every optional set). The random and full ones exercise
  # field combinations a single pinned test never would; the minimal one pins
  # the defaults the use case applies for omitted optionals.

  test "create a class", %{create_class: create_class} do
    broadcasts = subscribe_class_broadcasts()

    # Random fixtures: only what the test cannot do without is pinned (here,
    # nothing — the factory generates a unique name and otherwise-valid data).
    data = CourseFactory.build(:class_data, now: @now)
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, class} = create_class.(auth, data)

    class
    |> assert_created_class(data)
    |> assert_class_created_event(auth, data)
    |> assert_persisted_class()

    assert_row_count_diff(previous_counts, %{
      Class => 1,
      ExpectedServerProperties => 1,
      StoredEvent => 1
    })

    assert_class_created_broadcast(broadcasts, class)
  end

  test "create a minimal class", %{create_class: create_class} do
    broadcasts = subscribe_class_broadcasts()

    # Built by hand (rather than via the factory) so the minimal valid set is
    # explicit and does not drift: only the required fields, every optional left
    # at the value the use case applies when omitted (no dates, no teacher keys,
    # no SSH fingerprints).
    data = %{
      name: "Minimal Class",
      start_date: nil,
      end_date: nil,
      active: false,
      servers_enabled: false,
      teacher_ssh_public_keys: [],
      ssh_exercise_vm_md5_host_key_fingerprints: nil,
      ssh_exercise_vm_sha256_host_key_fingerprints: nil
    }

    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, class} = create_class.(auth, data)

    class
    |> assert_created_class(data)
    |> assert_class_created_event(auth, data)
    |> assert_persisted_class()

    assert_row_count_diff(previous_counts, %{
      Class => 1,
      ExpectedServerProperties => 1,
      StoredEvent => 1
    })

    assert_class_created_broadcast(broadcasts, class)
  end

  test "create a full class", %{create_class: create_class} do
    broadcasts = subscribe_class_broadcasts()

    # Built by hand with every optional set to a non-default value, so the test
    # pins that all of them — including the SSH host-key fingerprints — are
    # persisted and audited.
    data = %{
      name: "Full Class",
      start_date: ~D[2024-09-01],
      end_date: ~D[2025-01-31],
      active: true,
      servers_enabled: true,
      teacher_ssh_public_keys: [@teacher_ssh_public_key],
      ssh_exercise_vm_md5_host_key_fingerprints:
        SSHFactory.random_ssh_host_key_fingerprint_string(:md5),
      ssh_exercise_vm_sha256_host_key_fingerprints:
        SSHFactory.random_ssh_host_key_fingerprint_string(:sha256)
    }

    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, class} = create_class.(auth, data)

    class
    |> assert_created_class(data)
    |> assert_class_created_event(auth, data)
    |> assert_persisted_class()

    assert_row_count_diff(previous_counts, %{
      Class => 1,
      ExpectedServerProperties => 1,
      StoredEvent => 1
    })

    assert_class_created_broadcast(broadcasts, class)
  end

  test "a non-root user cannot create a class", %{create_class: create_class} do
    broadcasts = subscribe_class_broadcasts()

    data = CourseFactory.build(:class_data)
    auth = Factory.build(:authentication, root: false)

    previous_counts = count_rows(@affected_tables)

    assert_raise UnauthorizedError, fn -> create_class.(auth, data) end

    assert_no_class_persisted(broadcasts, previous_counts)
  end

  test "a class cannot be created with invalid data", %{create_class: create_class} do
    broadcasts = subscribe_class_broadcasts()

    data = CourseFactory.build(:class_data, name: "")
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:error, changeset} = create_class.(auth, data)
    assert errors_on(changeset) == %{name: ["can't be blank"]}

    assert_no_class_persisted(broadcasts, previous_counts)
  end

  test "a class cannot be created with a name that is already taken", %{
    create_class: create_class
  } do
    broadcasts = subscribe_class_broadcasts()

    existing = CourseFactory.insert(:class, name: "INFO-2024", now: @now)

    # The uniqueness check is case-insensitive.
    data = CourseFactory.build(:class_data, name: "info-2024")
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:error, changeset} = create_class.(auth, data)
    assert errors_on(changeset) == %{name: ["has already been taken"]}

    # The failed creation wrote nothing; the pre-existing class is untouched.
    assert persisted_class(existing.id) == existing
    assert_no_class_persisted(broadcasts, previous_counts)
  end

  test "validate valid class data without creating anything", %{validate_class: validate_class} do
    broadcasts = subscribe_class_broadcasts()

    data =
      CourseFactory.build(:class_data,
        name: "INFO-2024",
        teacher_ssh_public_keys: [@teacher_ssh_public_key]
      )

    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert %Changeset{} = changeset = validate_class.(auth, data)
    assert errors_on(changeset) == %{}

    # Validation is side-effect free.
    assert_no_class_persisted(broadcasts, previous_counts)
  end

  test "validate surfaces validation errors without creating anything", %{
    validate_class: validate_class
  } do
    broadcasts = subscribe_class_broadcasts()

    # One representative invalid value proves validation actually runs — the
    # function returns the changeset either way, with the errors in it.
    data = CourseFactory.build(:class_data, name: "")
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert %Changeset{} = changeset = validate_class.(auth, data)
    assert errors_on(changeset) == %{name: ["can't be blank"]}

    # Validation is side-effect free.
    assert_no_class_persisted(broadcasts, previous_counts)
  end

  test "a non-root user cannot validate class data", %{validate_class: validate_class} do
    broadcasts = subscribe_class_broadcasts()

    data = CourseFactory.build(:class_data)
    auth = Factory.build(:authentication, root: false)

    assert_raise UnauthorizedError, fn -> validate_class.(auth, data) end

    assert_no_stored_events!()
    assert received_broadcasts(broadcasts.global) == []
  end

  # Asserts the use case's return value exactly: the created class with every
  # field taken from the requested `data`, the common metadata stamped at the
  # pinned instant, and a freshly created blank expected-server-properties
  # association sharing the class id.
  defp assert_created_class(%Class{} = class, data) do
    assert %Class{id: id} = class

    assert class == %Class{
             __meta__: loaded(Class, "classes"),
             id: id,
             name: data.name,
             start_date: data.start_date,
             end_date: data.end_date,
             active: data.active,
             servers_enabled: data.servers_enabled,
             teacher_ssh_public_keys: data.teacher_ssh_public_keys,
             ssh_exercise_vm_md5_host_key_fingerprints:
               data.ssh_exercise_vm_md5_host_key_fingerprints,
             ssh_exercise_vm_sha256_host_key_fingerprints:
               data.ssh_exercise_vm_sha256_host_key_fingerprints,
             expected_server_properties: blank_expected_server_properties(id),
             expected_server_properties_id: id,
             version: 1,
             created_at: @now,
             updated_at: @now
           }

    class
  end

  defp assert_class_created_event(%Class{id: id}, auth, data) do
    assert [%StoredEvent{id: event_id} = created_event] = fetch_new_stored_events()

    assert created_event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "course:classes:#{id}",
             version: 1,
             schema_version: 1,
             type: "archidep/course/class-created",
             data: %{
               "id" => id,
               "name" => data.name,
               "start_date" => date_to_iso8601(data.start_date),
               "end_date" => date_to_iso8601(data.end_date),
               "active" => data.active,
               "servers_enabled" => data.servers_enabled,
               "teacher_ssh_public_keys" => data.teacher_ssh_public_keys,
               "ssh_exercise_vm_md5_host_key_fingerprints" =>
                 data.ssh_exercise_vm_md5_host_key_fingerprints,
               "ssh_exercise_vm_sha256_host_key_fingerprints" =>
                 data.ssh_exercise_vm_sha256_host_key_fingerprints
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

  # Reconstructs the expected persisted rows entirely from the already-asserted
  # audit event: the class fields it carries, plus what a "class created" event
  # implies — version 1, `updated_at` equal to `created_at`, and a blank
  # expected-server-properties row sharing the class id. The event stores dates
  # as ISO-8601 strings, so they are parsed back to `Date` structs.
  defp assert_persisted_class(%StoredEvent{
         data: %{
           "id" => id,
           "name" => name,
           "start_date" => start_date,
           "end_date" => end_date,
           "active" => active,
           "servers_enabled" => servers_enabled,
           "teacher_ssh_public_keys" => teacher_ssh_public_keys,
           "ssh_exercise_vm_md5_host_key_fingerprints" => md5_fingerprints,
           "ssh_exercise_vm_sha256_host_key_fingerprints" => sha256_fingerprints
         },
         occurred_at: created_at
       }) do
    assert persisted_class(id) == %Class{
             __meta__: loaded(Class, "classes"),
             id: id,
             name: name,
             start_date: date_from_iso8601(start_date),
             end_date: date_from_iso8601(end_date),
             active: active,
             servers_enabled: servers_enabled,
             teacher_ssh_public_keys: teacher_ssh_public_keys,
             ssh_exercise_vm_md5_host_key_fingerprints: md5_fingerprints,
             ssh_exercise_vm_sha256_host_key_fingerprints: sha256_fingerprints,
             expected_server_properties: blank_expected_server_properties(id),
             expected_server_properties_id: id,
             version: 1,
             created_at: created_at,
             updated_at: created_at
           }
  end

  defp blank_expected_server_properties(id) do
    %ExpectedServerProperties{
      __meta__: loaded(ExpectedServerProperties, "server_properties"),
      id: id,
      hostname: nil,
      machine_id: nil,
      cpus: nil,
      cores: nil,
      vcpus: nil,
      memory: nil,
      swap: nil,
      system: nil,
      architecture: nil,
      os_family: nil,
      distribution: nil,
      distribution_release: nil,
      distribution_version: nil
    }
  end

  defp persisted_class(id) do
    Repo.one!(
      from c in Class,
        where: c.id == ^id,
        preload: [:expected_server_properties]
    )
  end

  # Subscribes the single topic a class-created broadcast reaches — the global
  # classes topic — in its own collector, so its delivery is asserted on its
  # own.
  defp subscribe_class_broadcasts do
    %{global: collect_broadcasts(fn -> PubSub.subscribe_classes() end)}
  end

  # Asserts the class-created message reached the global classes topic exactly
  # once, carrying the created class, and nothing else.
  defp assert_class_created_broadcast(broadcasts, %Class{} = class) do
    assert received_broadcasts(broadcasts.global) == [{:class_created, class}]
  end

  # Asserts no class was created: no class or properties rows added, no event,
  # and the global classes topic stayed silent.
  defp assert_no_class_persisted(broadcasts, previous_counts) do
    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
    assert received_broadcasts(broadcasts.global) == []
  end
end
