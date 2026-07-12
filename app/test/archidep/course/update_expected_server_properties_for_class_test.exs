defmodule ArchiDep.Course.UpdateExpectedServerPropertiesForClassTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox

  import ArchiDep.Support.PubSubTestHelpers,
    only: [collect_broadcasts: 1, received_broadcasts: 1]

  alias ArchiDep.Clock
  alias ArchiDep.Course.Behaviour
  alias ArchiDep.Course.Context
  alias ArchiDep.Course.Events.ClassExpectedServerPropertiesUpdated
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.ExpectedServerProperties
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Repo
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.Factory
  alias Ecto.Changeset

  # Pinned instant returned by the injected clock for the duration of each test,
  # so that the class's `updated_at` and the event's `occurred_at` can be
  # asserted exactly (see docs/testing.md).
  @now ~U[2024-03-15 10:30:00.000000Z]

  # An instant safely before `@now`, used to persist the class fixtures in the
  # past so that an update visibly moves the class's `updated_at` forward.
  @past ~U[2023-09-15 09:42:17.000000Z]

  # Every expected-server-properties field set to a non-default value, built by
  # hand so that updating to it pins that each one is persisted and audited.
  @full_properties %{
    hostname: "server.example.com",
    machine_id: "abc123def456",
    cpus: 8,
    cores: 4,
    vcpus: 16,
    memory: 2048,
    swap: 1024,
    system: "Linux",
    architecture: "x86_64",
    os_family: "Debian",
    distribution: "Ubuntu",
    distribution_release: "noble",
    distribution_version: "24.04"
  }

  # Every expected-server-properties field reset to the value it carries when
  # left empty.
  @blank_properties %{
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
      update_expected_server_properties_for_class:
        protect({Context, :update_expected_server_properties_for_class, 3}, Behaviour),
      validate_expected_server_properties_for_class:
        protect({Context, :validate_expected_server_properties_for_class, 3}, Behaviour)
    }
  end

  # This use case updates a child association (the expected server properties)
  # while bumping the parent class's version and `updated_at`, and returns the
  # child. The three update tests below follow the update-testing strategy
  # documented in `docs/testing.md` applied to the child's fields: "update
  # everything" (start blank, set every property), "clear every optional" (start
  # full, reset every property), and a random one. Together the first two
  # exercise every property in both transition directions while pinning that the
  # parent's other fields are left untouched.

  test "update every expected server property", %{
    update_expected_server_properties_for_class: update
  } do
    # Start from a class whose properties are blank so that setting every one
    # exercises the empty -> set direction.
    original =
      CourseFactory.insert(:class, %{
        expected_server_properties:
          CourseFactory.build(:expected_server_properties, @blank_properties),
        now: @past
      })

    broadcasts = subscribe_class_broadcasts(original.id)

    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, properties} = update.(auth, original.id, @full_properties)

    assert_returned_properties(properties, original, @full_properties)

    event =
      original
      |> assert_properties_updated_event(auth, @full_properties)
      |> assert_persisted_class_and_properties(original, @full_properties)

    assert_row_count_diff(previous_counts, %{StoredEvent => 1})
    assert_class_updated_broadcast(broadcasts, original, event)
  end

  test "clear every expected server property", %{
    update_expected_server_properties_for_class: update
  } do
    # Start from a class whose properties are fully populated so that resetting
    # every one exercises the set -> empty direction and pins that the update
    # overwrites previously-set values rather than retaining them.
    original =
      CourseFactory.insert(:class, %{
        expected_server_properties:
          CourseFactory.build(:expected_server_properties, @full_properties),
        now: @past
      })

    broadcasts = subscribe_class_broadcasts(original.id)

    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, properties} = update.(auth, original.id, @blank_properties)

    assert_returned_properties(properties, original, @blank_properties)

    event =
      original
      |> assert_properties_updated_event(auth, @blank_properties)
      |> assert_persisted_class_and_properties(original, @blank_properties)

    assert_row_count_diff(previous_counts, %{StoredEvent => 1})
    assert_class_updated_broadcast(broadcasts, original, event)
  end

  test "update expected server properties with random data", %{
    update_expected_server_properties_for_class: update
  } do
    original = CourseFactory.insert(:class, %{now: @past})
    broadcasts = subscribe_class_broadcasts(original.id)

    # Random fixtures: the factory generates otherwise-valid property values,
    # exercising field combinations no single pinned test would.
    data = CourseFactory.build(:expected_server_properties_data)
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, properties} = update.(auth, original.id, data)

    assert_returned_properties(properties, original, data)

    event =
      original
      |> assert_properties_updated_event(auth, data)
      |> assert_persisted_class_and_properties(original, data)

    assert_row_count_diff(previous_counts, %{StoredEvent => 1})
    assert_class_updated_broadcast(broadcasts, original, event)
  end

  test "expected server properties cannot be updated with invalid data", %{
    update_expected_server_properties_for_class: update
  } do
    original = CourseFactory.insert(:class, %{now: @past})
    broadcasts = subscribe_class_broadcasts(original.id)

    # One representative invalid value (exhaustive per-field rules live in the
    # schema's own test). A too-large CPU count is still a `pos_integer`, so it
    # satisfies the input contract and reaches the changeset validation.
    data = Map.merge(@blank_properties, %{cpus: 100_000})
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:error, changeset} = update.(auth, original.id, data)
    assert errors_on(changeset) == %{cpus: ["must be between 1 and {number}"]}

    assert_update_had_no_effect(broadcasts, original, previous_counts)
  end

  test "expected server properties for a class that does not exist cannot be updated", %{
    update_expected_server_properties_for_class: update
  } do
    global = collect_broadcasts(fn -> PubSub.subscribe_classes() end)

    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert update.(auth, Ecto.UUID.generate(), @full_properties) == {:error, :class_not_found}

    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
    assert received_broadcasts(global) == []
  end

  test "a non-root user cannot update expected server properties", %{
    update_expected_server_properties_for_class: update
  } do
    original = CourseFactory.insert(:class, %{now: @past})
    broadcasts = subscribe_class_broadcasts(original.id)

    auth = Factory.build(:authentication, root: false)

    previous_counts = count_rows(@affected_tables)

    # The use case masks the authorization failure as :class_not_found so it
    # cannot leak the existence of a class the caller may not see.
    assert update.(auth, original.id, @full_properties) == {:error, :class_not_found}

    assert_update_had_no_effect(broadcasts, original, previous_counts)
  end

  test "validate valid expected server properties without changing anything", %{
    validate_expected_server_properties_for_class: validate
  } do
    original = CourseFactory.insert(:class, %{now: @past})
    broadcasts = subscribe_class_broadcasts(original.id)

    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, %Changeset{} = changeset} = validate.(auth, original.id, @full_properties)
    assert errors_on(changeset) == %{}

    # Validation is side-effect free.
    assert_update_had_no_effect(broadcasts, original, previous_counts)
  end

  test "validate surfaces validation errors without changing anything", %{
    validate_expected_server_properties_for_class: validate
  } do
    original = CourseFactory.insert(:class, %{now: @past})
    broadcasts = subscribe_class_broadcasts(original.id)

    # One representative invalid value proves validation actually runs — the
    # function returns the changeset either way, with the errors in it.
    data = Map.merge(@blank_properties, %{cpus: 100_000})
    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert {:ok, %Changeset{} = changeset} = validate.(auth, original.id, data)
    assert errors_on(changeset) == %{cpus: ["must be between 1 and {number}"]}

    # Validation is side-effect free.
    assert_update_had_no_effect(broadcasts, original, previous_counts)
  end

  test "validating expected server properties for a class that does not exist returns an error",
       %{validate_expected_server_properties_for_class: validate} do
    global = collect_broadcasts(fn -> PubSub.subscribe_classes() end)

    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert validate.(auth, Ecto.UUID.generate(), @full_properties) == {:error, :class_not_found}

    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
    assert received_broadcasts(global) == []
  end

  test "a non-root user cannot validate expected server properties", %{
    validate_expected_server_properties_for_class: validate
  } do
    original = CourseFactory.insert(:class, %{now: @past})
    broadcasts = subscribe_class_broadcasts(original.id)

    auth = Factory.build(:authentication, root: false)

    previous_counts = count_rows(@affected_tables)

    # Validation masks the authorization failure the same way the mutation does,
    # so an unauthorized caller cannot tell an existing class from an unknown
    # ID.
    assert validate.(auth, original.id, @full_properties) == {:error, :class_not_found}

    assert_update_had_no_effect(broadcasts, original, previous_counts)
  end

  # Asserts the use case's return value exactly: the class's expected server
  # properties (identity preserved) with every field overwritten by the
  # requested `data`.
  defp assert_returned_properties(
         %ExpectedServerProperties{} = properties,
         %Class{} = original,
         data
       ) do
    assert properties == %ExpectedServerProperties{
             __meta__: loaded(ExpectedServerProperties, "server_properties"),
             id: original.expected_server_properties.id,
             hostname: data.hostname,
             machine_id: data.machine_id,
             cpus: data.cpus,
             cores: data.cores,
             vcpus: data.vcpus,
             memory: data.memory,
             swap: data.swap,
             system: data.system,
             architecture: data.architecture,
             os_family: data.os_family,
             distribution: data.distribution,
             distribution_release: data.distribution_release,
             distribution_version: data.distribution_version
           }

    properties
  end

  # Asserts the single `ClassExpectedServerPropertiesUpdated` event: a
  # denormalized reference to the parent class (id and name, unchanged by a
  # properties-only update) plus every property field, in the class's stream at
  # the bumped version, stamped at the pinned instant.
  defp assert_properties_updated_event(%Class{id: id, name: name, version: version}, auth, data) do
    assert [%StoredEvent{id: event_id} = updated_event] = fetch_new_stored_events()

    assert updated_event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "course:classes:#{id}",
             version: version + 1,
             schema_version: 1,
             type: "archidep/course/class-expected-server-properties-updated",
             data: %{
               "class" => %{"id" => id, "name" => name},
               "hostname" => data.hostname,
               "machine_id" => data.machine_id,
               "cpus" => data.cpus,
               "cores" => data.cores,
               "vcpus" => data.vcpus,
               "memory" => data.memory,
               "swap" => data.swap,
               "system" => data.system,
               "architecture" => data.architecture,
               "os_family" => data.os_family,
               "distribution" => data.distribution,
               "distribution_release" => data.distribution_release,
               "distribution_version" => data.distribution_version
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

  # Reconstructs the expected persisted rows from the already-asserted event and
  # the original baseline: the class is the original with only its version
  # bumped and `updated_at` advanced (every other field untouched — the thing a
  # sub-aspect update must not disturb), and its properties carry the event's
  # values.
  defp assert_persisted_class_and_properties(
         %StoredEvent{version: version, occurred_at: updated_at} = event,
         %Class{} = original,
         data
       ) do
    properties = %ExpectedServerProperties{
      __meta__: loaded(ExpectedServerProperties, "server_properties"),
      id: original.expected_server_properties.id,
      hostname: data.hostname,
      machine_id: data.machine_id,
      cpus: data.cpus,
      cores: data.cores,
      vcpus: data.vcpus,
      memory: data.memory,
      swap: data.swap,
      system: data.system,
      architecture: data.architecture,
      os_family: data.os_family,
      distribution: data.distribution,
      distribution_release: data.distribution_release,
      distribution_version: data.distribution_version
    }

    assert persisted_class(original.id) == %Class{
             original
             | expected_server_properties: properties,
               version: version,
               updated_at: updated_at
           }

    event
  end

  # Subscribes the two topics a class-updated broadcast reaches — the class's
  # own topic and the global classes topic — each in its own collector, so each
  # topic's delivery is asserted on its own.
  defp subscribe_class_broadcasts(class_id) do
    %{
      specific: collect_broadcasts(fn -> PubSub.subscribe_class(class_id) end),
      global: collect_broadcasts(fn -> PubSub.subscribe_classes() end)
    }
  end

  # Asserts the class-updated message reached both topics the use case publishes
  # to — the class-specific one and the global one — each carrying the
  # `ClassExpectedServerPropertiesUpdated` domain event and the stored-event
  # reference, and nothing else.
  defp assert_class_updated_broadcast(broadcasts, %Class{} = original, %StoredEvent{} = event) do
    expected_class = persisted_class(original.id)
    expected_reference = StoredEvent.to_reference(event)

    expected_event =
      ClassExpectedServerPropertiesUpdated.new(
        expected_class.expected_server_properties,
        expected_class
      )

    expected_message = {:class_updated, expected_event, expected_reference}

    assert received_broadcasts(broadcasts.specific) == [expected_message]
    assert received_broadcasts(broadcasts.global) == [expected_message]
  end

  # Asserts neither class topic carried an update broadcast.
  defp refute_class_updated_broadcast(broadcasts) do
    assert received_broadcasts(broadcasts.specific) == []
    assert received_broadcasts(broadcasts.global) == []
  end

  defp persisted_class(id) do
    Repo.one!(
      from c in Class,
        where: c.id == ^id,
        preload: [:expected_server_properties]
    )
  end

  # Asserts a rejected or side-effect-free call left no trace: the class and its
  # properties are unchanged, no rows were added or removed anywhere, and no
  # event or broadcast was emitted. `previous_counts` must be captured before
  # the call.
  defp assert_update_had_no_effect(broadcasts, %Class{} = original, previous_counts) do
    assert persisted_class(original.id) == original
    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
    refute_class_updated_broadcast(broadcasts)
  end
end
