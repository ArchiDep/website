defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  import Ecto.Query, only: [from: 2]
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.ServersFactory

  test "initialize a server manager for a new server" do
    server = generate_server!()

    assert ServerManagerState.init(server.id, __MODULE__) == %ServerManagerState{
             server: server,
             pipeline: __MODULE__,
             username: server.username,
             actions: [track_server_action(server, real_time_state(server))]
           }
  end

  test "initializing a server manager for a server that has already been set up uses the app username instead of the username" do
    now = DateTime.utc_now()
    server = generate_server!(set_up_at: now)

    assert ServerManagerState.init(server.id, __MODULE__) == %ServerManagerState{
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
  end

  test "initializing a server with a failed setup ansible playbook run indicates a problem" do
    server = generate_server!()
    failed_run = ServersFactory.insert(:ansible_playbook_run, server: server, state: :failed)

    assert ServerManagerState.init(server.id, __MODULE__) == %ServerManagerState{
             server: server,
             pipeline: __MODULE__,
             username: server.username,
             actions: [
               track_server_action(
                 server,
                 real_time_state(server, problems: [server_ansible_playbook_failed(failed_run)])
               )
             ],
             problems: [server_ansible_playbook_failed(failed_run)]
           }
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

  defp real_time_state(server, attrs! \\ []) do
    {conn_params, attrs!} = Keyword.pop_lazy(attrs!, :conn_params, fn -> conn_params(server) end)
    {problems, attrs!} = Keyword.pop(attrs!, :problems, [])
    {set_up_at, attrs!} = Keyword.pop_lazy(attrs!, :set_up_at, fn -> server.set_up_at end)

    [] = Keyword.keys(attrs!)

    %ServerRealTimeState{
      connection_state: not_connected_state(),
      name: server.name,
      conn_params: conn_params,
      username: server.username,
      app_username: server.app_username,
      current_job: nil,
      problems: problems,
      set_up_at: set_up_at,
      version: 0
    }
  end

  defp conn_params(server, attrs! \\ []) do
    {username, attrs!} = Keyword.pop(attrs!, :username, server.username)

    [] = Keyword.keys(attrs!)

    {server.ip_address.address, server.ssh_port || 22, username}
  end

  defp server_ansible_playbook_failed(ansible_playbook_run),
    do:
      {:server_ansible_playbook_failed, ansible_playbook_run.playbook, :failed,
       ansible_stats(ansible_playbook_run)}

  defp ansible_stats(ansible_playbook_run),
    do: %{
      changed: ansible_playbook_run.stats_changed,
      failures: ansible_playbook_run.stats_failures,
      ignored: ansible_playbook_run.stats_ignored,
      ok: ansible_playbook_run.stats_ok,
      rescued: ansible_playbook_run.stats_rescued,
      skipped: ansible_playbook_run.stats_skipped,
      unreachable: ansible_playbook_run.stats_unreachable
    }

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
