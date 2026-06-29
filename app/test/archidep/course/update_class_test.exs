defmodule ArchiDep.Course.UpdateClassTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox
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

  # An instant safely before `@now`, used to persist the class fixtures in the
  # past so that an update visibly moves their `updated_at` forward to `@now`.
  @past ~U[2023-09-15 09:42:17.000000Z]

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
      update_class: protect({Context, :update_class, 3}, Behaviour),
      validate_existing_class: protect({Context, :validate_existing_class, 3}, Behaviour)
    }
  end

  # The three update tests below follow the update-testing strategy documented
  # in `docs/testing.md`, the mirror of the create strategy: "update everything"
  # (start from a minimal class and set every field — the empty -> set
  # direction), "clear every optional" (start from a full class and reset every
  # optional to its default — the full -> empty direction), and a random one
  # (let the factory pick the new data). Together the first two exercise every
  # optional in both transition directions.

  test "update every field of a class", %{update_class: update_class} do
    :ok = PubSub.subscribe_classes()

    # Start from a minimal class (every optional at its default) so that
    # updating every field to a non-default value exercises the empty -> set
    # direction for each optional, and so every field genuinely differs
    # before/after — a field missing from the update changeset's cast list would
    # then fail to change and be caught here.
    original =
      CourseFactory.insert(:class, %{
        name: "Before",
        start_date: nil,
        end_date: nil,
        active: false,
        servers_enabled: false,
        teacher_ssh_public_keys: [],
        ssh_exercise_vm_md5_host_key_fingerprints: nil,
        ssh_exercise_vm_sha256_host_key_fingerprints: nil,
        now: @past
      })

    :ok = PubSub.subscribe_class(original.id)

    # Built by hand with every field set to a non-default value, so the test
    # pins that all of them — including the SSH host-key fingerprints — are
    # persisted and audited on update.
    data = %{
      name: "After",
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

    assert {:ok, class} = update_class.(auth, original.id, data)

    event =
      class
      |> assert_updated_class(original, data)
      |> assert_class_updated_event(auth, data)
      |> assert_persisted_class(original)

    assert_row_count_diff(previous_counts, %{StoredEvent => 1})
    assert_class_updated_broadcast(class, event)
  end

  test "clear every optional field of a class", %{update_class: update_class} do
    :ok = PubSub.subscribe_classes()

    # Start from a fully-populated class so that clearing every optional
    # exercises the full -> empty direction and pins that the update overwrites
    # previously set values rather than retaining them.
    original =
      CourseFactory.insert(:class, %{
        name: "Before",
        start_date: ~D[2024-09-01],
        end_date: ~D[2025-01-31],
        active: true,
        servers_enabled: true,
        teacher_ssh_public_keys: [@teacher_ssh_public_key],
        ssh_exercise_vm_md5_host_key_fingerprints:
          SSHFactory.random_ssh_host_key_fingerprint_string(:md5),
        ssh_exercise_vm_sha256_host_key_fingerprints:
          SSHFactory.random_ssh_host_key_fingerprint_string(:sha256),
        now: @past
      })

    :ok = PubSub.subscribe_class(original.id)

    # Built by hand: only the required fields, every optional reset to the value
    # a class carries when left empty.
    data = %{
      name: "After",
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

    assert {:ok, class} = update_class.(auth, original.id, data)

    event =
      class
      |> assert_updated_class(original, data)
      |> assert_class_updated_event(auth, data)
      |> assert_persisted_class(original)

    assert_row_count_diff(previous_counts, %{StoredEvent => 1})
    assert_class_updated_broadcast(class, event)
  end

  test "update a class with random data", %{update_class: update_class} do
    :ok = PubSub.subscribe_classes()

    original = CourseFactory.insert(:class, %{now: @past})
    :ok = PubSub.subscribe_class(original.id)

    # Random fixtures: the factory generates a unique name and otherwise-valid
    # data, exercising field combinations no single pinned test would.
    data = CourseFactory.build(:class_data, now: @now)
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, class} = update_class.(auth, original.id, data)

    event =
      class
      |> assert_updated_class(original, data)
      |> assert_class_updated_event(auth, data)
      |> assert_persisted_class(original)

    assert_row_count_diff(previous_counts, %{StoredEvent => 1})
    assert_class_updated_broadcast(class, event)
  end

  test "a class can be updated while keeping its own name", %{update_class: update_class} do
    :ok = PubSub.subscribe_classes()

    # The uniqueness check excludes the class being updated, so re-saving a
    # class with its own name succeeds.
    original = CourseFactory.insert(:class, %{name: "INFO-2024", now: @past})
    :ok = PubSub.subscribe_class(original.id)

    data = CourseFactory.build(:class_data, name: "INFO-2024", now: @now)
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, class} = update_class.(auth, original.id, data)

    event =
      class
      |> assert_updated_class(original, data)
      |> assert_class_updated_event(auth, data)
      |> assert_persisted_class(original)

    assert_row_count_diff(previous_counts, %{StoredEvent => 1})
    assert_class_updated_broadcast(class, event)
  end

  test "a non-root user cannot update a class", %{update_class: update_class} do
    original = CourseFactory.insert(:class, %{now: @past})

    :ok = PubSub.subscribe_classes()
    :ok = PubSub.subscribe_class(original.id)

    data = CourseFactory.build(:class_data, now: @now)
    auth = Factory.build(:authentication, root: false)

    previous_counts = count_rows(@affected_tables)

    assert_raise UnauthorizedError, fn -> update_class.(auth, original.id, data) end

    assert_update_had_no_effect(original, previous_counts)
  end

  test "a class that does not exist cannot be updated", %{update_class: update_class} do
    :ok = PubSub.subscribe_classes()

    data = CourseFactory.build(:class_data, now: @now)
    root = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    # A well-formed but unknown ID reports the class as missing.
    assert update_class.(root, Ecto.UUID.generate(), data) == {:error, :class_not_found}

    # The missing class is reported before the authorization check, so even a
    # non-root caller gets :class_not_found rather than an authorization error.
    non_root = Factory.build(:authentication, root: false)
    assert update_class.(non_root, Ecto.UUID.generate(), data) == {:error, :class_not_found}

    assert_no_class_persisted(previous_counts)
  end

  test "a class cannot be updated with invalid data", %{update_class: update_class} do
    original = CourseFactory.insert(:class, %{now: @past})

    :ok = PubSub.subscribe_classes()
    :ok = PubSub.subscribe_class(original.id)

    data = CourseFactory.build(:class_data, name: "", now: @now)
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:error, changeset} = update_class.(auth, original.id, data)
    assert errors_on(changeset) == %{name: ["can't be blank"]}

    assert_update_had_no_effect(original, previous_counts)
  end

  test "a class cannot be renamed to a name that is already taken", %{update_class: update_class} do
    other = CourseFactory.insert(:class, %{name: "INFO-2024", now: @past})
    original = CourseFactory.insert(:class, %{name: "ARCH-2024", now: @past})

    :ok = PubSub.subscribe_classes()
    :ok = PubSub.subscribe_class(original.id)

    # The uniqueness check is case-insensitive.
    data = CourseFactory.build(:class_data, name: "info-2024", now: @now)
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:error, changeset} = update_class.(auth, original.id, data)
    assert errors_on(changeset) == %{name: ["has already been taken"]}

    # Neither class changed, no event was stored and no broadcast was emitted.
    assert_class_unchanged(other)
    assert_update_had_no_effect(original, previous_counts)
  end

  test "validate valid update data for an existing class without changing anything", %{
    validate_existing_class: validate_existing_class
  } do
    original = CourseFactory.insert(:class, %{now: @past})

    :ok = PubSub.subscribe_classes()
    :ok = PubSub.subscribe_class(original.id)

    data =
      CourseFactory.build(:class_data,
        name: "INFO-2024",
        teacher_ssh_public_keys: [@teacher_ssh_public_key],
        now: @now
      )

    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, %Changeset{} = changeset} = validate_existing_class.(auth, original.id, data)
    assert errors_on(changeset) == %{}

    # Validation is side-effect free.
    assert_update_had_no_effect(original, previous_counts)
  end

  test "validate surfaces validation errors for an existing class without changing anything", %{
    validate_existing_class: validate_existing_class
  } do
    original = CourseFactory.insert(:class, %{now: @past})

    :ok = PubSub.subscribe_classes()
    :ok = PubSub.subscribe_class(original.id)

    # One representative invalid value proves validation actually runs — the
    # function returns the changeset either way, with the errors in it.
    data = CourseFactory.build(:class_data, name: "", now: @now)
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, %Changeset{} = changeset} = validate_existing_class.(auth, original.id, data)
    assert errors_on(changeset) == %{name: ["can't be blank"]}

    # Validation is side-effect free.
    assert_update_had_no_effect(original, previous_counts)
  end

  test "validating update data for a class that does not exist returns an error", %{
    validate_existing_class: validate_existing_class
  } do
    data = CourseFactory.build(:class_data, now: @now)
    auth = Factory.build(:authentication, root: true)

    assert validate_existing_class.(auth, Ecto.UUID.generate(), data) ==
             {:error, :class_not_found}

    assert_no_stored_events!()
  end

  test "a non-root user cannot validate update data for a class", %{
    validate_existing_class: validate_existing_class
  } do
    original = CourseFactory.insert(:class, %{now: @past})

    :ok = PubSub.subscribe_classes()
    :ok = PubSub.subscribe_class(original.id)

    data = CourseFactory.build(:class_data, now: @now)
    auth = Factory.build(:authentication, root: false)

    previous_counts = count_rows(@affected_tables)

    assert_raise UnauthorizedError, fn -> validate_existing_class.(auth, original.id, data) end

    assert_update_had_no_effect(original, previous_counts)
  end

  # Asserts the use case's return value exactly: the original class with every
  # field overwritten by the requested `data`, the version bumped by one, the
  # `created_at` and expected-server-properties association preserved, and
  # `updated_at` stamped at the pinned instant.
  defp assert_updated_class(%Class{} = class, %Class{} = original, data) do
    assert class == %Class{
             __meta__: loaded(Class, "classes"),
             id: original.id,
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
             expected_server_properties: original.expected_server_properties,
             expected_server_properties_id: original.expected_server_properties_id,
             version: original.version + 1,
             created_at: original.created_at,
             updated_at: @now
           }

    class
  end

  defp assert_class_updated_event(%Class{id: id, version: version}, auth, data) do
    assert [%StoredEvent{id: event_id} = updated_event] = fetch_new_stored_events()

    assert updated_event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "course:classes:#{id}",
             version: version,
             type: "archidep/course/class-updated",
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

    updated_event
  end

  # Reconstructs the expected persisted row from the already-asserted audit
  # event for every field the event carries (parsing the ISO-8601 dates back to
  # `Date` structs), and from the original baseline for what an update leaves
  # untouched: `created_at` and the expected-server-properties association. The
  # version and `updated_at` come from the event (which carries the bumped
  # version and the update instant). Returns the event so it can be consumed by
  # the next step of the assertion pipeline.
  defp assert_persisted_class(
         %StoredEvent{
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
           version: version,
           occurred_at: updated_at
         } = event,
         %Class{} = original
       ) do
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
             expected_server_properties: original.expected_server_properties,
             expected_server_properties_id: original.expected_server_properties_id,
             version: version,
             created_at: original.created_at,
             updated_at: updated_at
           }

    event
  end

  defp persisted_class(id) do
    Repo.one!(
      from c in Class,
        where: c.id == ^id,
        preload: [:expected_server_properties]
    )
  end

  # Asserts the class-updated message reached both topics the use case publishes
  # to — the class-specific one and the global one — each carrying the updated
  # class and a reference to the stored event, and that nothing else was
  # broadcast.
  defp assert_class_updated_broadcast(%Class{} = class, %StoredEvent{} = event) do
    expected_reference = StoredEvent.to_reference(event)

    assert_receive {:class_updated, class_specific, reference_specific}
    assert_receive {:class_updated, global, reference_global}

    assert class_specific == class
    assert global == class
    assert reference_specific == expected_reference
    assert reference_global == expected_reference

    refute_received {:class_updated, _, _}
  end

  defp refute_class_updated_broadcast do
    refute_received {:class_updated, _, _}
  end

  # Asserts a class row is exactly as it was. Used to check a class left
  # untouched by a rejected update.
  defp assert_class_unchanged(%Class{} = class) do
    assert persisted_class(class.id) == class
  end

  # Asserts a rejected update left no trace: the class row is unchanged, no rows
  # were added or removed anywhere, and no event or broadcast was emitted.
  # `previous_counts` must be captured before the call.
  defp assert_update_had_no_effect(%Class{} = original, previous_counts) do
    assert_class_unchanged(original)
    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
    refute_class_updated_broadcast()
  end

  # Asserts the full set of effects that must NOT happen when no class exists to
  # update: no class or properties rows added, no event, no broadcast.
  defp assert_no_class_persisted(previous_counts) do
    assert_no_row_count_diff(previous_counts)
    # No event stored already proves no broadcast (emitted only after the update
    # commits); there is no class ID to scope a refute to.
    assert_no_stored_events!()
  end
end
