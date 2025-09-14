defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateInitTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Support.ServerManagerStateTestUtils
  import Hammox
  alias ArchiDep.Servers.ServerTracking.ServerManagerBehaviour
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Support.ServersFactory

  setup :verify_on_exit!

  setup_all do
    %{init: protect({ServerManagerState, :init, 2}, ServerManagerBehaviour)}
  end

  test "initialize a server manager for a new server", %{init: init} do
    server = insert_active_server!(set_up_at: nil)

    assert init.(server.id, __MODULE__) == %ServerManagerState{
             server: server,
             pipeline: __MODULE__,
             username: server.username,
             actions: [track_server_action(server, real_time_state(server))]
           }

    assert_no_stored_events!()
  end

  test "initializing a server manager for a server that has already been set up uses the app username instead of the username",
       %{init: init} do
    now = DateTime.utc_now()
    server = insert_active_server!(set_up_at: now)

    assert init.(server.id, __MODULE__) == %ServerManagerState{
             server: server,
             pipeline: __MODULE__,
             username: server.app_username,
             actions: [
               track_server_action(
                 server,
                 real_time_state(server,
                   conn_params: conn_params(server, username: server.app_username),
                   set_up_at: now
                 )
               )
             ]
           }

    assert_no_stored_events!()
  end

  test "initializing a server with a failed setup ansible playbook run indicates a problem", %{
    init: init
  } do
    server = insert_active_server!(set_up_at: nil)
    failed_run = ServersFactory.insert(:ansible_playbook_run, server: server, state: :failed)
    problem = ServersFactory.server_ansible_playbook_failed_problem(playbook_run: failed_run)

    assert init.(server.id, __MODULE__) == %ServerManagerState{
             server: server,
             pipeline: __MODULE__,
             username: server.username,
             actions: [
               track_server_action(
                 server,
                 real_time_state(server, problems: [problem])
               )
             ],
             problems: [problem]
           }

    assert_no_stored_events!()
  end

  defp track_server_action(server, state), do: {:track, "servers", server.id, state}
end
