defmodule ArchiDep.Servers.ServerCallbacksTest do
  use ArchiDep.Support.DataCase, async: true

  import ExUnit.CaptureLog
  import Hammox
  import ArchiDep.Support.TelemetryTestHelpers
  alias ArchiDep.Clock
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias ArchiDep.Servers.ServerTracking.ServerManagerClientMock
  alias ArchiDep.Servers.UseCases.ServerCallbacks
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.ServersTestHelpers
  alias Ecto.UUID
  alias Phoenix.Token

  @now ~U[2024-03-15 10:30:00.000000Z]
  @past ~U[2023-09-15 09:42:17.000000Z]
  @telemetry_event [:archidep, :servers, :tracking, :up]

  @affected_tables [Server, ServerProperties, StoredEvent]

  setup :verify_on_exit!

  setup context do
    stub(Clock.Mock, :now, fn -> @now end)
    attach_telemetry_handler!(context, @telemetry_event)
    :ok
  end

  test "notifies the server manager that a server came up" do
    server = insert_server()
    server_id = server.id
    token = Token.sign(server.secret_key, "server auth", server_id)
    previous_counts = count_rows(@affected_tables)
    test_pid = self()

    expect(ServerManagerClientMock, :notify_server_up, fn ^server_id, ref ->
      send(test_pid, {:notified_up, ref})
      :ok
    end)

    assert ServerCallbacks.notify_server_up(server_id, token) == :ok

    event = assert_server_notified_up_event(server)

    assert_received {:notified_up, ref}
    assert ref == StoredEvent.to_reference(event)

    assert_row_count_diff(previous_counts, %{StoredEvent => 1})

    assert assert_telemetry_event!(@telemetry_event) == %{
             measurements: %{},
             metadata: %{server_id: server_id},
             config: nil
           }
  end

  test "rejects a malformed server ID" do
    previous_counts = count_rows(@affected_tables)

    assert ServerCallbacks.notify_server_up("not-a-uuid", "some-token") ==
             {:error, :server_not_found}

    assert_no_side_effects(previous_counts)
  end

  test "rejects an unknown server ID" do
    previous_counts = count_rows(@affected_tables)

    assert ServerCallbacks.notify_server_up(UUID.generate(), "some-token") ==
             {:error, :server_not_found}

    assert_no_side_effects(previous_counts)
  end

  test "rejects an expired token" do
    server = insert_server()
    # A token signed at the Unix epoch is older than the one-year validity
    # window, so verification fails as expired.
    token = Token.sign(server.secret_key, "server auth", server.id, signed_at: 0)
    previous_counts = count_rows(@affected_tables)

    assert ServerCallbacks.notify_server_up(server.id, token) == {:error, :server_not_found}

    assert_no_side_effects(previous_counts)
  end

  test "rejects an invalid token, logging a warning" do
    server = insert_server()
    previous_counts = count_rows(@affected_tables)

    log =
      capture_log(fn ->
        assert ServerCallbacks.notify_server_up(server.id, "not-a-valid-token") ==
                 {:error, :server_not_found}
      end)

    assert log =~ "Received invalid server token"
    assert_no_side_effects(previous_counts)
  end

  test "rejects a token signed for a different server, logging a warning" do
    server = insert_server()
    token = Token.sign(server.secret_key, "server auth", UUID.generate())
    previous_counts = count_rows(@affected_tables)

    log =
      capture_log(fn ->
        assert ServerCallbacks.notify_server_up(server.id, token) == {:error, :server_not_found}
      end)

    assert log =~ "Server ID mismatch"
    assert_no_side_effects(previous_counts)
  end

  defp insert_server do
    {_auth, account} = ServersTestHelpers.register_root(@past)
    group = CourseFactory.insert(:class, now: @past)
    ServersTestHelpers.insert_server(account.id, group.id, active: true)
  end

  defp assert_server_notified_up_event(%Server{id: id, version: version} = server) do
    assert [%StoredEvent{id: event_id} = event] = fetch_new_stored_events()

    assert event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "servers:servers:#{id}",
             version: version,
             type: "archidep/servers/server-notified-up",
             data: %{
               "id" => id,
               "name" => server.name,
               "ip_address" => to_string(:inet.ntoa(server.ip_address.address)),
               "username" => server.username,
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
             initiator: "servers:servers:#{id}",
             causation_id: event_id,
             correlation_id: event_id,
             occurred_at: @now,
             entity: nil
           }

    event
  end

  defp assert_no_side_effects(previous_counts) do
    assert_no_row_count_diff(previous_counts)
    assert_no_stored_events!()
    refute_received {:telemetry_event, @telemetry_event, _data}
    refute_received {:notified_up, _ref}
  end

  defp owner_name(%ServerOwner{group_member: %{name: name}}), do: name
  defp owner_name(%ServerOwner{group_member: nil}), do: nil
end
