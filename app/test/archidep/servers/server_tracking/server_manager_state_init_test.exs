defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateInitTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Support.ServerManagerStateTestUtils
  import Ecto.Query, only: [from: 2]
  import Hammox
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerTracking.ServerManagerBehaviour
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.ServersFactory

  setup :verify_on_exit!

  setup_all do
    %{init: protect({ServerManagerState, :init, 2}, ServerManagerBehaviour)}
  end

  test "initialize a server manager for a new server", %{init: init} do
    server = generate_server!()

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
    server = generate_server!(set_up_at: now)

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
    server = generate_server!()
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

  defp generate_server!(attrs \\ []) do
    user_account = AccountsFactory.insert(:user_account)
    course = CourseFactory.insert(:class, servers_enabled: true)

    incomplete_server =
      ServersFactory.insert(
        :server,
        Keyword.merge(
          [active: true, owner_id: user_account.id, group_id: course.id, set_up_at: nil],
          attrs
        )
      )

    fetch_server!(incomplete_server.id)
  end

  defp track_server_action(server, state), do: {:track, "servers", server.id, state}

  defp fetch_server!(id),
    do:
      Repo.one!(
        from s in Server,
          join: o in assoc(s, :owner),
          left_join: ogm in assoc(o, :group_member),
          left_join: ogmg in assoc(ogm, :group),
          join: g in assoc(s, :group),
          join: gesp in assoc(g, :expected_server_properties),
          join: ep in assoc(s, :expected_properties),
          left_join: lkp in assoc(s, :last_known_properties),
          where: s.id == ^id,
          preload: [
            group: {g, expected_server_properties: gesp},
            expected_properties: ep,
            last_known_properties: lkp,
            owner: {o, group_member: {ogm, group: ogmg}}
          ]
      )
end
