defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateResetServerSetupTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  import ArchiDep.Support.ServerManagerStateTestUtils
  import Hammox

  import ArchiDep.Support.PubSubTestHelpers,
    only: [collect_broadcasts: 1, received_broadcasts: 1]

  alias ArchiDep.Clock
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Servers.Events.ServerSetupReset
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias ArchiDep.Servers.ServerTracking.ServerManagerBehaviour
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.Factory
  alias ArchiDep.Support.ServersFactory

  @now ~U[2026-02-17 08:15:42.123456Z]

  @affected_tables [Server, ServerProperties, StoredEvent]

  setup :verify_on_exit!

  setup do
    stub(Clock.Mock, :now, fn -> @now end)
    :ok
  end

  setup_all do
    %{
      reset_server_setup:
        protect({ServerManagerState, :reset_server_setup, 2}, ServerManagerBehaviour)
    }
  end

  test "reset the setup of a server whose application user cannot authenticate", %{
    reset_server_setup: reset_server_setup
  } do
    server = insert_active_server!(set_up_at: true, open_ports_checked_at: true, ssh_port: true)
    auth = Factory.build(:authentication, root: true)

    property_mismatch = {:server_expected_property_mismatch, :cpus, 2, 1}

    %ServerManagerState{} =
      initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connection_failed_state(),
        server: server,
        username: server.app_username,
        problems: [
          {:server_authentication_failed, :app_username, server.app_username},
          property_mismatch
        ]
      )

    previous_counts = count_rows(@affected_tables)
    subscriptions = subscribe(server)

    result = reset_server_setup.(initial_state, auth)

    {updated_server, event_ref} =
      assert_server_setup_reset!(server, auth, previous_counts, subscriptions)

    test_pid = self()

    assert {%ServerManagerState{
              connection_state: connecting_state(connection_ref: connection_ref, time: time),
              actions:
                [
                  {:connect, connect_fn},
                  {:update_tracking, "servers", update_tracking_fn}
                ] = actions
            } = new_state, :ok} = result

    assert result ==
             {%ServerManagerState{
                initial_state
                | connection_state:
                    connecting_state(
                      connection_ref: connection_ref,
                      connection_pid: test_pid,
                      time: time,
                      retrying: false,
                      causation_event: event_ref
                    ),
                  server: updated_server,
                  username: server.username,
                  problems: [property_mismatch],
                  actions: actions
              }, :ok}

    assert_connecting_as_initial_user!(
      new_state,
      connect_fn,
      update_tracking_fn,
      updated_server,
      [property_mismatch]
    )
  end

  test "reset the setup of a server that is waiting to retry connecting", %{
    reset_server_setup: reset_server_setup
  } do
    server = insert_active_server!(set_up_at: true, ssh_port: true)
    auth = Factory.build(:authentication, root: true)

    property_mismatch = {:server_expected_property_mismatch, :memory, 2048, 1024}
    retry_timer = make_ref()

    %ServerManagerState{} =
      initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_retry_connecting_state(),
        server: server,
        username: server.app_username,
        retry_timer: retry_timer,
        problems: [
          {:server_connection_timed_out, server.ip_address.address, server.ssh_port,
           server.app_username},
          property_mismatch,
          {:server_key_exchange_failed, nil, nil},
          {:server_reconnection_failed, :closed}
        ]
      )

    previous_counts = count_rows(@affected_tables)
    subscriptions = subscribe(server)

    result = reset_server_setup.(initial_state, auth)

    {updated_server, event_ref} =
      assert_server_setup_reset!(server, auth, previous_counts, subscriptions)

    test_pid = self()

    assert {%ServerManagerState{
              connection_state: connecting_state(connection_ref: connection_ref, time: time),
              actions:
                [
                  {:connect, connect_fn},
                  {:cancel_timer, ^retry_timer},
                  {:update_tracking, "servers", update_tracking_fn}
                ] = actions
            } = new_state, :ok} = result

    assert result ==
             {%ServerManagerState{
                initial_state
                | connection_state:
                    connecting_state(
                      connection_ref: connection_ref,
                      connection_pid: test_pid,
                      time: time,
                      retrying: false,
                      causation_event: event_ref
                    ),
                  server: updated_server,
                  username: server.username,
                  problems: [property_mismatch],
                  retry_timer: nil,
                  actions: actions
              }, :ok}

    assert_connecting_as_initial_user!(
      new_state,
      connect_fn,
      update_tracking_fn,
      updated_server,
      [property_mismatch]
    )
  end

  test "reset the setup of a connected server that is idle", %{
    reset_server_setup: reset_server_setup
  } do
    server = insert_active_server!(set_up_at: true, open_ports_checked_at: true, ssh_port: true)
    auth = Factory.build(:authentication, root: true)

    property_mismatch = {:server_expected_property_mismatch, :hostname, "foo", "bar"}
    load_average_timer = make_ref()

    %ServerManagerState{} =
      initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        load_average_timer: load_average_timer,
        problems: [
          {:server_fact_gathering_failed, :boom},
          {:server_port_testing_script_failed, {:exit, 2, "oops"}},
          property_mismatch,
          {:server_open_ports_check_failed, [{80, :econnrefused}]},
          {:server_missing_sudo_access, server.app_username, "not in the sudoers file"}
        ]
      )

    previous_counts = count_rows(@affected_tables)
    subscriptions = subscribe(server)

    result = reset_server_setup.(initial_state, auth)

    {updated_server, event_ref} =
      assert_server_setup_reset!(server, auth, previous_counts, subscriptions)

    test_pid = self()

    assert {%ServerManagerState{
              connection_state: connecting_state(connection_ref: connection_ref, time: time),
              actions:
                [
                  {:connect, connect_fn},
                  {:update_tracking, "servers", update_tracking_fn},
                  {:cancel_timer, ^load_average_timer}
                ] = actions
            } = new_state, :ok} = result

    assert result ==
             {%ServerManagerState{
                initial_state
                | connection_state:
                    connecting_state(
                      connection_ref: connection_ref,
                      connection_pid: test_pid,
                      time: time,
                      retrying: false,
                      causation_event: event_ref
                    ),
                  server: updated_server,
                  username: server.username,
                  problems: [property_mismatch],
                  load_average_timer: nil,
                  actions: actions
              }, :ok}

    assert_connecting_as_initial_user!(
      new_state,
      connect_fn,
      update_tracking_fn,
      updated_server,
      [property_mismatch]
    )
  end

  for {description, connection_state_fn} <- [
        {"a server that is not connected", &ServersFactory.random_not_connected_state/0},
        {"a server with a pending connection", &ServersFactory.random_connection_pending_state/0},
        {"a disconnected server", &ServersFactory.random_disconnected_state/0}
      ] do
    test "reset the setup of #{description} without connecting", %{
      reset_server_setup: reset_server_setup
    } do
      server = insert_active_server!(set_up_at: true, open_ports_checked_at: true)
      auth = Factory.build(:authentication, root: true)

      kept_problems = [{:server_expected_property_mismatch, :vcpus, 4, 2}]

      connection_state = unquote(connection_state_fn).()
      connection_timer = make_ref()

      %ServerManagerState{} =
        initial_state =
        ServersFactory.build(:server_manager_state,
          connection_state: connection_state,
          server: server,
          username: server.app_username,
          connection_timer: connection_timer,
          problems: [
            {:server_connection_refused, server.ip_address.address, server.ssh_port || 22,
             server.app_username},
            {:server_sudo_access_check_failed, server.app_username, :timeout}
            | kept_problems
          ]
        )

      previous_counts = count_rows(@affected_tables)
      subscriptions = subscribe(server)

      result = reset_server_setup.(initial_state, auth)

      {updated_server, _event_ref} =
        assert_server_setup_reset!(server, auth, previous_counts, subscriptions)

      assert {%ServerManagerState{
                actions: [{:update_tracking, "servers", update_tracking_fn}] = actions
              } = new_state, :ok} = result

      assert result ==
               {%ServerManagerState{
                  initial_state
                  | server: updated_server,
                    username: server.username,
                    problems: kept_problems,
                    actions: actions
                }, :ok}

      assert update_tracking_fn.(new_state) ==
               {real_time_state(updated_server,
                  connection_state: connection_state,
                  problems: kept_problems,
                  version: initial_state.version + 1
                ), %ServerManagerState{new_state | version: initial_state.version + 1}}
    end
  end

  test "cannot reset the setup of a server that is busy", %{
    reset_server_setup: reset_server_setup
  } do
    server = insert_active_server!(set_up_at: true, open_ports_checked_at: true)
    auth = Factory.build(:authentication, root: true)
    persisted = Repo.get!(Server, server.id)

    previous_counts = count_rows(@affected_tables)
    subscriptions = subscribe(server)

    for {busy_state, tasks, ansible} <- [
          {ServersFactory.random_connecting_state(), %{}, nil},
          {ServersFactory.random_reconnecting_state(), %{}, nil},
          {ServersFactory.random_connected_state(), %{get_load_average: make_ref()}, nil},
          {ServersFactory.random_connected_state(), %{},
           {ServersFactory.build(:ansible_playbook_run, server: server, state: :pending), nil,
            EventsFactory.build(:event_reference)}},
          {ServersFactory.random_connected_state(), %{}, :gathering_facts}
        ] do
      initial_state =
        ServersFactory.build(:server_manager_state,
          connection_state: busy_state,
          server: server,
          username: server.app_username,
          tasks: tasks,
          ansible: ansible
        )

      assert reset_server_setup.(initial_state, auth) == {initial_state, {:error, :server_busy}}
    end

    assert_nothing_reset!(server, persisted, previous_counts, subscriptions)
  end

  test "resetting the setup of a server that is not set up does nothing", %{
    reset_server_setup: reset_server_setup
  } do
    server = insert_active_server!(set_up_at: nil)
    auth = Factory.build(:authentication, root: true)
    persisted = Repo.get!(Server, server.id)

    previous_counts = count_rows(@affected_tables)
    subscriptions = subscribe(server)

    for connection_state <- [
          ServersFactory.random_not_connected_state(),
          ServersFactory.random_connection_pending_state(),
          ServersFactory.random_connected_state(),
          ServersFactory.random_retry_connecting_state(),
          ServersFactory.random_connection_failed_state(),
          ServersFactory.random_disconnected_state()
        ] do
      initial_state =
        ServersFactory.build(:server_manager_state,
          connection_state: connection_state,
          server: server,
          username: server.username,
          problems: [{:server_authentication_failed, :username, server.username}]
        )

      assert reset_server_setup.(initial_state, auth) == {initial_state, :ok}
    end

    assert_nothing_reset!(server, persisted, previous_counts, subscriptions)
  end

  # Asserts the whole effect of a setup reset outside the state: the audit
  # event, the persisted row rebuilt from it, the row-count diff and the
  # broadcasts. Returns the server the state should now hold (the original one,
  # associations included, with its setup forgotten) and the event reference.
  defp assert_server_setup_reset!(
         %Server{} = server,
         auth,
         previous_counts,
         subscriptions
       ) do
    event = assert_server_setup_reset_event!(server, auth)
    assert_persisted_server!(event, server)
    assert_row_count_diff(previous_counts, %{StoredEvent => 1})

    event_ref = StoredEvent.to_reference(event)

    updated_server = %Server{
      server
      | set_up_at: nil,
        open_ports_checked_at: nil,
        version: event.version,
        updated_at: event.occurred_at
    }

    broadcast = {:server_updated, ServerSetupReset.new(updated_server), event_ref}

    assert received_broadcasts(subscriptions.server) == [broadcast]
    assert received_broadcasts(subscriptions.group) == [broadcast]
    assert received_broadcasts(subscriptions.owner) == [broadcast]

    {updated_server, event_ref}
  end

  defp assert_server_setup_reset_event!(%Server{id: id} = server, auth) do
    assert [%StoredEvent{id: event_id} = event] = fetch_new_stored_events()

    assert event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "servers:servers:#{id}",
             version: server.version + 1,
             schema_version: 1,
             type: "archidep/servers/server-setup-reset",
             data: %{
               "id" => id,
               "name" => server.name,
               "ip_address" => server.ip_address.address |> :inet.ntoa() |> to_string(),
               "username" => server.username,
               "app_username" => server.app_username,
               "ssh_port" => server.ssh_port,
               "group" => %{"id" => server.group.id, "name" => server.group.name},
               "owner" => %{
                 "id" => server.owner.id,
                 "username" => server.owner.username,
                 "name" => owner_name(server.owner),
                 "root" => server.owner.root
               }
             },
             meta: %{},
             initiator: "accounts:user-accounts:#{auth.principal_id}",
             causation_id: event_id,
             correlation_id: event_id,
             occurred_at: @now,
             entity: nil
           }

    event
  end

  # The fields the event does not carry are left untouched by a reset, so they
  # come from the original server.
  defp assert_persisted_server!(
         %StoredEvent{data: event_data, version: version, occurred_at: occurred_at},
         original
       ) do
    id = event_data["id"]

    assert Repo.get!(Server, id) == %Server{
             __meta__: loaded(Server, "servers"),
             id: id,
             name: event_data["name"],
             ip_address: parse_inet(event_data["ip_address"]),
             username: event_data["username"],
             app_username: event_data["app_username"],
             ssh_port: event_data["ssh_port"],
             ssh_host_keys: original.ssh_host_keys,
             secret_key: original.secret_key,
             active: original.active,
             group: not_loaded(:group, Server),
             group_id: event_data["group"]["id"],
             owner: not_loaded(:owner, Server),
             owner_id: event_data["owner"]["id"],
             expected_properties: not_loaded(:expected_properties, Server),
             expected_properties_id: original.expected_properties_id,
             last_known_properties: not_loaded(:last_known_properties, Server),
             last_known_properties_id: original.last_known_properties_id,
             version: version,
             created_at: original.created_at,
             set_up_at: nil,
             open_ports_checked_at: nil,
             updated_at: occurred_at
           }
  end

  defp assert_nothing_reset!(server, persisted, previous_counts, subscriptions) do
    assert_no_stored_events!()
    assert_no_row_count_diff(previous_counts)
    assert Repo.get!(Server, server.id) == persisted
    assert received_broadcasts(subscriptions.server) == []
    assert received_broadcasts(subscriptions.group) == []
    assert received_broadcasts(subscriptions.owner) == []
  end

  # Proves that the manager connects as the server's initial user, and that the
  # tracked real-time state reflects the reset.
  defp assert_connecting_as_initial_user!(
         %ServerManagerState{} = new_state,
         connect_fn,
         update_tracking_fn,
         %Server{} = updated_server,
         expected_problems
       ) do
    %ServerManagerState{} =
      connect_result = assert_connect_fn!(connect_fn, new_state, updated_server.username)

    assert update_tracking_fn.(connect_result) ==
             {real_time_state(updated_server,
                connection_state: new_state.connection_state,
                current_job: :connecting,
                problems: expected_problems,
                version: new_state.version + 1
              ), %ServerManagerState{connect_result | version: new_state.version + 1}}
  end

  defp subscribe(%Server{} = server) do
    %{
      server: collect_broadcasts(fn -> PubSub.subscribe_server(server.id) end),
      group: collect_broadcasts(fn -> PubSub.subscribe_server_group_servers(server.group_id) end),
      owner: collect_broadcasts(fn -> PubSub.subscribe_server_owner_servers(server.owner_id) end)
    }
  end

  defp owner_name(%ServerOwner{group_member: %{name: name}}), do: name
  defp owner_name(%ServerOwner{group_member: nil}), do: nil

  defp parse_inet(string) do
    {:ok, inet} = EctoNetwork.INET.cast(string)
    inet
  end
end
