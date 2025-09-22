defmodule ArchiDep.Support.ServerManagerStateTestUtils do
  @moduledoc """
  Utility functions for testing server manager state handling.
  """

  import ArchiDep.Helpers.PipeHelpers
  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  import Ecto.Query, only: [from: 2]
  import ExUnit.Assertions
  import ExUnit.Callbacks
  import ExUnit.CaptureLog
  alias ArchiDep.Repo
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDep.Servers.ServerTracking.ServerConnection
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Servers.SSH
  alias ArchiDep.Servers.SSH.SSHKeyFingerprint
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.FactoryHelpers
  alias ArchiDep.Support.GenServerProxy
  alias ArchiDep.Support.NetFactory
  alias ArchiDep.Support.ServersFactory
  alias Ecto.UUID

  @type connect_fn :: (ServerManagerState.t(),
                       (:inet.ip_address(), 1..65_535, String.t(), Keyword.t() -> Task.t()) ->
                         ServerManagerState.t())

  @spec assert_connect_fn!(connect_fn(), ServerManagerState.t(), String.t()) ::
          ServerManagerState.t()
  def assert_connect_fn!(connect_fn, state, username) do
    fake_task = Task.completed(:fake)

    test_pid = self()
    server = state.server
    expected_host = server.ip_address.address
    expected_port = server.ssh_port || 22

    result =
      connect_fn.(state, fn ^expected_host, ^expected_port, ^username, opts! ->
        assert {{:sha256, silently_accept_hosts}, opts!} =
                 Keyword.pop!(opts!, :silently_accept_hosts)

        assert Keyword.keys(opts!) == []
        send(test_pid, {:connect_called, silently_accept_hosts})
        fake_task
      end)

    assert result == %ServerManagerState{state | tasks: %{connect: fake_task.ref}}

    assert_receive {:connect_called, silently_accept_hosts_fn}, 500
    assert is_function(silently_accept_hosts_fn, 2)

    assert {:ok, ssh_host_key_fingerprints, []} =
             SSH.parse_ssh_host_key_fingerprints(server.ssh_host_key_fingerprints)

    for fingerprint <- ssh_host_key_fingerprints do
      random_peer = :inet.ntoa(NetFactory.ip_address())

      assert silently_accept_hosts_fn.(
               random_peer,
               SSHKeyFingerprint.fingerprint_human(fingerprint)
             ) == true
    end

    refute_received {:unknown_key_fingerprint, _unknown_fingerprint}

    random_peer = :inet.ntoa(NetFactory.ip_address())
    unknown_fingerprint = ServersFactory.random_ssh_host_key_fingerprint_digest()

    assert {false, msg} =
             with_log(fn -> silently_accept_hosts_fn.(random_peer, unknown_fingerprint) end)

    assert msg =~
             "Refusing to connect to server #{server.id} because its SSH host key fingerprint #{inspect(unknown_fingerprint)} does not match any of the expected fingerprints"

    assert_receive {:unknown_key_fingerprint, ^unknown_fingerprint}, 500

    result
  end

  @spec build_active_server(Keyword.t()) :: Server.t()
  def build_active_server(opts! \\ []) do
    {group, opts!} =
      Keyword.pop_lazy(opts!, :group, fn ->
        ServersFactory.build(:server_group, active: true, servers_enabled: true)
      end)

    {root, opts!} = Keyword.pop_lazy(opts!, :root, &FactoryHelpers.bool/0)

    member =
      if root do
        nil
      else
        ServersFactory.build(:server_group_member, active: true, group: group)
      end

    owner = ServersFactory.build(:server_owner, active: true, root: root, group_member: member)

    ServersFactory.build(
      :server,
      Keyword.merge([active: true, group: group, group_id: group.id, owner: owner], opts!)
    )
  end

  @spec insert_active_server!(Keyword.t()) :: Server.t()
  def insert_active_server!(opts!) do
    class_id = UUID.generate()

    {class_expected_server_properties, opts!} =
      Keyword.pop(opts!, :class_expected_server_properties, [])

    expected_server_properties =
      CourseFactory.insert(
        :expected_server_properties,
        Keyword.merge(class_expected_server_properties, id: class_id)
      )

    {class_teacher_ssh_public_keys, opts!} =
      Keyword.pop(opts!, :class_teacher_ssh_public_keys, [])

    class =
      CourseFactory.insert(:class,
        id: class_id,
        active: true,
        servers_enabled: true,
        teacher_ssh_public_keys: class_teacher_ssh_public_keys,
        expected_server_properties: expected_server_properties
      )

    {:ok, group} = ServerGroup.fetch_server_group(class.id)

    {root, opts!} = Keyword.pop_lazy(opts!, :root, &FactoryHelpers.bool/0)
    server_active = Keyword.get(opts!, :active, true)

    user_account =
      if root do
        user_account = AccountsFactory.insert(:user_account, active: true, root: true)
        user_account_id = user_account.id

        Repo.update_all(from(so in ServerOwner, where: so.id == ^user_account_id),
          set: [server_count: 1, active_server_count: if(server_active, do: 1, else: 0)]
        )

        user_account
      else
        student =
          CourseFactory.insert(:student,
            active: true,
            class: class,
            class_id: group.id,
            user: nil
          )

        user_account =
          AccountsFactory.insert(:user_account,
            root: false,
            active: true,
            preregistered_user_id: student.id
          )

        student_id = student.id
        user_account_id = user_account.id

        Repo.update_all(from(so in ServerOwner, where: so.id == ^user_account_id),
          set: [server_count: 1, active_server_count: if(server_active, do: 1, else: 0)]
        )

        Repo.update_all(from(sgm in ServerGroupMember, where: sgm.id == ^student_id),
          set: [owner_id: user_account.id]
        )

        user_account
      end

    owner = user_account.id |> ServerOwner.fetch_server_owner() |> unpair_ok()

    id = UUID.generate()

    {server_expected_properties, opts!} =
      Keyword.pop(opts!, :server_expected_properties, [])

    expected_properties =
      ServersFactory.insert(:server_properties, Keyword.merge(server_expected_properties, id: id))

    {server_last_known_properties, opts!} = Keyword.pop(opts!, :server_last_known_properties, [])

    last_known_properties =
      if server_last_known_properties == [] do
        nil
      else
        ServersFactory.insert(
          :server_properties,
          Keyword.merge(server_last_known_properties, id: UUID.generate())
        )
      end

    ServersFactory.insert(
      :server,
      Keyword.merge(
        [
          id: id,
          active: true,
          group: group,
          group_id: group.id,
          owner: owner,
          owner_id: owner.id,
          expected_properties: expected_properties,
          last_known_properties: last_known_properties
        ],
        opts!
      )
    )

    id |> Server.fetch_server() |> unpair_ok()
  end

  @spec real_time_state(Server.t(), Keyword.t()) :: ServerRealTimeState.t()
  def real_time_state(server, attrs! \\ []) do
    {connection_state, attrs!} =
      Keyword.pop_lazy(attrs!, :connection_state, fn -> not_connected_state() end)

    {conn_params, attrs!} = Keyword.pop_lazy(attrs!, :conn_params, fn -> conn_params(server) end)
    {username, attrs!} = Keyword.pop(attrs!, :username, server.username)
    {app_username, attrs!} = Keyword.pop(attrs!, :app_username, server.app_username)
    {current_job, attrs!} = Keyword.pop(attrs!, :current_job, nil)
    {problems, attrs!} = Keyword.pop(attrs!, :problems, [])
    {set_up_at, attrs!} = Keyword.pop_lazy(attrs!, :set_up_at, fn -> server.set_up_at end)
    {version, attrs!} = Keyword.pop(attrs!, :version, 0)

    [] = Keyword.keys(attrs!)

    %ServerRealTimeState{
      connection_state: connection_state,
      name: server.name,
      conn_params: conn_params,
      username: username,
      app_username: app_username,
      current_job: current_job,
      problems: problems,
      set_up_at: set_up_at,
      version: version
    }
  end

  @spec conn_params(Server.t(), Keyword.t()) :: {:inet.ip_address(), 1..65_535, String.t()}
  def conn_params(server, attrs! \\ []) do
    {username, attrs!} = Keyword.pop(attrs!, :username, server.username)

    [] = Keyword.keys(attrs!)

    {server.ip_address.address, server.ssh_port || 22, username}
  end

  @spec ssh_public_key() :: String.t()
  def ssh_public_key,
    do: :archidep |> Application.fetch_env!(:servers) |> Keyword.fetch!(:ssh_public_key)

  @spec assert_server_connection_disconnected!(Server.t(), (-> result)) :: result
        when result: var
  def assert_server_connection_disconnected!(server, fun) do
    server_conn_name = ServerConnection.name(server)

    # Start a fake server connection process that will forward all calls to the
    # test process.
    start_link_supervised!(%{
      id: ServerConnection,
      start: {GenServerProxy, :start_link, [self(), server_conn_name]}
    })

    result_task = Task.async(fun)

    assert_receive {:proxy, ^server_conn_name, {:call, :disconnect, from}}
    :ok = GenServer.reply(from, :ok)

    Task.await(result_task)
  end
end
