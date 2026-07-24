defmodule ArchiDep.Course.DeleteClassTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox

  import ArchiDep.Support.PubSubTestHelpers,
    only: [collect_broadcasts: 1, received_broadcasts: 1]

  alias ArchiDep.Clock
  alias ArchiDep.Course.Behaviour
  alias ArchiDep.Course.Context
  alias ArchiDep.Course.Events.ClassDeleted
  alias ArchiDep.Course.PubSub
  alias ArchiDep.Course.Schemas.Class
  alias ArchiDep.Course.Schemas.ExpectedServerProperties
  alias ArchiDep.Errors.UnauthorizedError
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Repo
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.Factory
  alias ArchiDep.Support.ServersFactory

  # Pinned instant returned by the injected clock for the duration of each test,
  # so that the deletion event's `occurred_at` can be asserted exactly (see
  # docs/testing.md).
  @now ~U[2024-03-15 10:30:00.000000Z]

  # An instant safely before `@now`, used to persist the class fixtures in the
  # past so that the deletion is visibly stamped at `@now` rather than at the
  # fixture's own timestamps.
  @past ~U[2023-09-15 09:42:17.000000Z]

  # Every table this use case can affect. Snapshot all of them with
  # `count_rows/1` before each call so the row-count diff catches a stray write
  # to any of them, not just the ones a given test happens to think about (see
  # docs/testing.md). `Server` is watched because a server's foreign key is what
  # blocks (or fails to block) a class deletion.
  @affected_tables [Class, ExpectedServerProperties, StoredEvent, Server]

  setup :verify_on_exit!

  setup do
    stub(Clock.Mock, :now, fn -> @now end)
    :ok
  end

  setup_all do
    %{delete_class: protect({Context, :delete_class, 2}, Behaviour)}
  end

  # A delete has no input fields to vary, so unlike create/update it gets a
  # single happy-path test (see `docs/testing.md`).

  test "delete a class", %{delete_class: delete_class} do
    class = CourseFactory.insert(:class, now: @past)
    broadcasts = subscribe_class_broadcasts(class.id)

    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert delete_class.(auth, class.id) == :ok

    event = assert_class_deleted_event(class, auth)

    class
    |> assert_class_gone()
    |> assert_class_deleted_broadcast(broadcasts, event)

    assert_row_count_diff(previous_counts, %{
      Class => -1,
      ExpectedServerProperties => -1,
      StoredEvent => 1
    })
  end

  test "a class with servers cannot be deleted", %{delete_class: delete_class} do
    class = CourseFactory.insert(:class, now: @past)

    # The class itself is the server group the server belongs to (server groups
    # and classes share the `classes` table); a server also needs an owner (a
    # user account — `root: true` only to satisfy the user-account check
    # constraint) and its two server-properties rows.
    owner = AccountsFactory.insert(:user_account, root: true)
    expected_properties = ServersFactory.insert(:server_properties)
    last_known_properties = ServersFactory.insert(:server_properties)

    server =
      ServersFactory.insert(:server,
        group_id: class.id,
        owner_id: owner.id,
        expected_properties: expected_properties,
        last_known_properties: last_known_properties
      )

    broadcasts = subscribe_class_broadcasts(class.id)

    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows(@affected_tables)

    assert delete_class.(auth, class.id) == {:error, :class_has_servers}

    # The whole transaction rolled back.
    assert persisted_class(class.id) == class
    assert Repo.get!(Server, server.id).id == server.id
    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
    refute_class_deleted_broadcast(broadcasts)
  end

  test "a class that does not exist cannot be deleted", %{delete_class: delete_class} do
    global = collect_broadcasts(fn -> PubSub.subscribe_classes() end)

    previous_counts = count_rows(@affected_tables)

    root = Factory.build(:authentication, root: true)
    assert delete_class.(root, Ecto.UUID.generate()) == {:error, :class_not_found}

    # Not-found is reported before the authorization check, so a non-root caller
    # also gets :class_not_found rather than an authorization error.
    non_root = Factory.build(:authentication, root: false)
    assert delete_class.(non_root, Ecto.UUID.generate()) == {:error, :class_not_found}

    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
    assert received_broadcasts(global) == []
  end

  test "a non-root user cannot delete a class", %{delete_class: delete_class} do
    class = CourseFactory.insert(:class, now: @past)
    broadcasts = subscribe_class_broadcasts(class.id)

    auth = Factory.build(:authentication, root: false)

    previous_counts = count_rows(@affected_tables)

    assert_raise UnauthorizedError, fn -> delete_class.(auth, class.id) end

    assert persisted_class(class.id) == class
    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
    refute_class_deleted_broadcast(broadcasts)
  end

  # Asserts the single `ClassDeleted` event: the deleted class's identity in its
  # stream, at the class's current version (a delete does not bump it), stamped
  # at the pinned instant.
  defp assert_class_deleted_event(%Class{id: id, name: name, version: version}, auth) do
    assert [%StoredEvent{id: event_id} = deleted_event] = fetch_new_stored_events()

    assert deleted_event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "course:classes:#{id}",
             version: version,
             schema_version: 1,
             type: "archidep/course/class-deleted",
             data: %{
               "id" => id,
               "name" => name
             },
             meta: %{},
             initiator: "accounts:user-accounts:#{auth.principal_id}",
             causation_id: event_id,
             correlation_id: event_id,
             occurred_at: @now,
             entity: nil
           }

    deleted_event
  end

  # Asserts this specific class and its owned expected-server-properties row no
  # longer exist. The use case deletes the properties explicitly because the
  # foreign key is on the `classes` table, so a missing delete would orphan
  # them.
  defp assert_class_gone(%Class{id: id, expected_server_properties_id: properties_id} = class) do
    refute Repo.exists?(from c in Class, where: c.id == ^id)
    refute Repo.exists?(from p in ExpectedServerProperties, where: p.id == ^properties_id)
    class
  end

  # Subscribes the two topics a class-deleted broadcast reaches — the class's
  # own topic and the global classes topic — each in its own collector, so each
  # topic's delivery is asserted on its own.
  defp subscribe_class_broadcasts(class_id) do
    %{
      specific: collect_broadcasts(fn -> PubSub.subscribe_class(class_id) end),
      global: collect_broadcasts(fn -> PubSub.subscribe_classes() end)
    }
  end

  # Asserts the class-deleted message reached both topics the use case publishes
  # to — the class-specific one and the global one — each carrying the
  # `ClassDeleted` domain event and the stored-event reference, and nothing
  # else.
  defp assert_class_deleted_broadcast(%Class{} = class, broadcasts, %StoredEvent{} = event) do
    expected_message = {:class_deleted, ClassDeleted.new(class), StoredEvent.to_reference(event)}
    assert received_broadcasts(broadcasts.specific) == [expected_message]
    assert received_broadcasts(broadcasts.global) == [expected_message]

    class
  end

  # Asserts neither class topic carried a delete broadcast.
  defp refute_class_deleted_broadcast(broadcasts) do
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
end
