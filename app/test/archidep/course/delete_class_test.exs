defmodule ArchiDep.Course.DeleteClassTest do
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
    :ok = PubSub.subscribe_classes()

    class = CourseFactory.insert(:class, now: @past)
    :ok = PubSub.subscribe_class(class.id)

    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows([Class, ExpectedServerProperties, StoredEvent])

    assert delete_class.(auth, class.id) == :ok

    class
    |> assert_class_deleted_event(auth)
    |> assert_class_gone()
    |> assert_class_deleted_broadcast()

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

    :ok = PubSub.subscribe_classes()
    :ok = PubSub.subscribe_class(class.id)

    auth = Factory.build(:authentication, root: true)

    previous_counts = count_rows([Class, ExpectedServerProperties, Server, StoredEvent])

    assert delete_class.(auth, class.id) == {:error, :class_has_servers}

    # The whole transaction rolled back.
    assert persisted_class(class.id) == class
    assert Repo.get!(Server, server.id).id == server.id
    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
    refute_class_deleted_broadcast(class.id)
  end

  test "a class that does not exist cannot be deleted", %{delete_class: delete_class} do
    :ok = PubSub.subscribe_classes()

    root = Factory.build(:authentication, root: true)
    assert delete_class.(root, Ecto.UUID.generate()) == {:error, :class_not_found}

    # Not-found is reported before the authorization check, so a non-root caller
    # also gets :class_not_found rather than an authorization error.
    non_root = Factory.build(:authentication, root: false)
    assert delete_class.(non_root, Ecto.UUID.generate()) == {:error, :class_not_found}

    # No event stored already proves no broadcast (the use case broadcasts only
    # after the deletion commits); there is no class ID to scope a refute to.
    assert_no_stored_events!()
  end

  test "a non-root user cannot delete a class", %{delete_class: delete_class} do
    class = CourseFactory.insert(:class, now: @past)

    :ok = PubSub.subscribe_classes()
    :ok = PubSub.subscribe_class(class.id)

    auth = Factory.build(:authentication, root: false)

    previous_counts = count_rows([Class, ExpectedServerProperties])

    assert_raise UnauthorizedError, fn -> delete_class.(auth, class.id) end

    assert persisted_class(class.id) == class
    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
    refute_class_deleted_broadcast(class.id)
  end

  # Asserts the single `ClassDeleted` event: the deleted class's identity in its
  # stream, at the class's current version (a delete does not bump it), stamped
  # at the pinned instant.
  defp assert_class_deleted_event(%Class{id: id, name: name, version: version} = class, auth) do
    assert [%StoredEvent{id: event_id} = deleted_event] = fetch_new_stored_events()

    assert deleted_event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "course:classes:#{id}",
             version: version,
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

    class
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

  # Asserts the class-deleted message reached both the class-specific and global
  # topics, and that nothing else was broadcast.
  defp assert_class_deleted_broadcast(%Class{id: id} = class) do
    # Pin the class ID so the assertions match only this test's broadcasts — the
    # global "classes" topic is shared across async tests and not sandboxed (see
    # docs/testing.md).
    assert_receive {:class_deleted, %Class{id: ^id} = class_specific}
    assert_receive {:class_deleted, %Class{id: ^id} = global}

    assert class_specific == class
    assert global == class

    refute_received {:class_deleted, %Class{id: ^id}}

    class
  end

  defp refute_class_deleted_broadcast(id) do
    refute_received {:class_deleted, %Class{id: ^id}}
  end

  defp persisted_class(id) do
    Repo.one!(
      from c in Class,
        where: c.id == ^id,
        preload: [:expected_server_properties]
    )
  end
end
