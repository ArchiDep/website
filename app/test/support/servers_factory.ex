defmodule ArchiDep.Support.ServersFactory do
  @moduledoc """
  Test fixtures for the servers context.
  """

  use ArchiDep.Support, :factory

  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  alias ArchiDep.Events.Store.EventReference
  alias ArchiDep.Servers.Ansible
  alias ArchiDep.Servers.Schemas.AnsiblePlaybook
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookEvent
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias ArchiDep.Servers.ServerTracking.ServerConnectionState
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Servers.Types
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.NetFactory
  alias ArchiDep.Support.SSHFactory
  alias Ecto.UUID

  @playbooks [AnsiblePlaybook.name(Ansible.setup_playbook())]
  @failed_ansible_playbook_run_states [:failed, :interrupted, :timeout]
  @finished_ansible_playbook_run_states [:succeeded] ++ @failed_ansible_playbook_run_states

  @spec ansible_playbook_event_factory(map()) :: AnsiblePlaybookEvent.t()
  def ansible_playbook_event_factory(attrs!) do
    {id, attrs!} = pop_entity_id(attrs!)
    {run, attrs!} = Map.pop_lazy(attrs!, :run, fn -> build(:ansible_playbook_run) end)
    {run_id, attrs!} = Map.pop_lazy(attrs!, :run_id, fn -> run.id end)
    {name, attrs!} = Map.pop_lazy(attrs!, :name, &Faker.Lorem.word/0)
    {action, attrs!} = Map.pop_lazy(attrs!, :action, optionally(&Faker.Lorem.word/0))
    {changed, attrs!} = Map.pop_lazy(attrs!, :changed, &bool/0)

    {data, attrs!} =
      Map.pop_lazy(attrs!, :data, fn -> %{"value" => Faker.random_between(1, 1_000_000)} end)

    {task_name, attrs!} = Map.pop_lazy(attrs!, :task_name, optionally(&Faker.Lorem.sentence/0))
    {task_id, attrs!} = Map.pop_lazy(attrs!, :task_id, optionally(&UUID.generate/0))

    {task_started_at, attrs!} =
      Map.pop_lazy(attrs!, :task_started_at, optionally(fn -> Faker.DateTime.backward(5) end))

    {task_ended_at, attrs!} =
      Map.pop_lazy(attrs!, :task_ended_at, optionally(fn -> Faker.DateTime.backward(3) end))

    {occurred_at, attrs!} =
      Map.pop_lazy(attrs!, :occurred_at, fn -> Faker.DateTime.backward(1) end)

    {created_at, attrs!} =
      Map.pop_lazy(attrs!, :occurred_at, fn -> Faker.DateTime.backward(1) end)

    [] = Map.keys(attrs!)

    %AnsiblePlaybookEvent{
      id: id,
      run: run,
      run_id: run_id,
      name: name,
      action: action,
      changed: changed,
      data: data,
      task_name: task_name,
      task_id: task_id,
      task_started_at: task_started_at,
      task_ended_at: task_ended_at,
      occurred_at: occurred_at,
      created_at: created_at
    }
  end

  @spec ansible_playbook_run_factory(map()) :: AnsiblePlaybookRun.t()
  def ansible_playbook_run_factory(attrs!) do
    {id, attrs!} = pop_entity_id(attrs!)
    {playbook, attrs!} = Map.pop_lazy(attrs!, :playbook, fn -> Enum.random(@playbooks) end)

    {playbook_path, attrs!} =
      Map.pop_lazy(
        attrs!,
        :playbook_path,
        fn -> sequence(:ansible_playbook_run_playbook_path, &"/playbooks/playbook-#{&1}.yml") end
      )

    {playbook_digest, attrs!} = Map.pop_lazy(attrs!, :playbook_digest, &Faker.String.base64/0)

    {git_revision, attrs!} =
      Map.pop_lazy(
        attrs!,
        :git_revision,
        fn -> sequence(:ansible_playbook_run_git_revision, &"rev-#{&1}") end
      )

    {host, attrs!} = Map.pop_lazy(attrs!, :host, &NetFactory.postgrex_inet/0)
    {port, attrs!} = Map.pop_lazy(attrs!, :port, &NetFactory.port/0)

    {user, attrs!} =
      Map.pop_lazy(attrs!, :user, fn -> sequence(:ansible_playbook_run_user, &"user#{&1}") end)

    {vars, attrs!} =
      Map.pop_lazy(attrs!, :vars, fn ->
        %{"ansible_connection" => "ssh", "ansible_user" => user}
      end)

    {vars_digest, attrs!} = Map.pop_lazy(attrs!, :vars_digest, fn -> Faker.random_bytes(10) end)

    {server, attrs!} = Map.pop(attrs!, :server, not_loaded(:server, AnsiblePlaybookRun))

    {server_id, attrs!} =
      Map.pop_lazy(attrs!, :server_id, fn ->
        case server do
          %NotLoaded{} -> UUID.generate()
          %Server{} -> server.id
        end
      end)

    {state, attrs!} = Map.pop_lazy(attrs!, :state, &ansible_playbook_run_state/0)

    {started_at, attrs!} =
      Map.pop_lazy(
        attrs!,
        :started_at,
        fn ->
          if state == :pending do
            nil
          else
            DateTime.add(DateTime.utc_now(), -Faker.random_between(1, 300), :second)
          end
        end
      )

    {finished_at, attrs!} =
      Map.pop_lazy(attrs!, :finished_at, fn ->
        if Enum.member?(@finished_ansible_playbook_run_states, state) and started_at != nil do
          Faker.DateTime.between(started_at, DateTime.utc_now())
        else
          nil
        end
      end)

    {number_of_events, attrs!} = Map.pop(attrs!, :number_of_events, 0)
    {last_event_at, attrs!} = Map.pop(attrs!, :last_event_at, nil)

    {exit_code, attrs!} =
      Map.pop_lazy(attrs!, :exit_code, fn ->
        if Enum.member?(@finished_ansible_playbook_run_states, state) do
          Faker.random_between(0, 255)
        else
          nil
        end
      end)

    {stats_changed, attrs!} =
      Map.pop_lazy(attrs!, :stats_changed, fn -> Faker.random_between(0, 10) end)

    {stats_failures, attrs!} =
      Map.pop_lazy(attrs!, :stats_failures, fn -> Faker.random_between(0, 10) end)

    {stats_ignored, attrs!} =
      Map.pop_lazy(attrs!, :stats_ignored, fn -> Faker.random_between(0, 10) end)

    {stats_ok, attrs!} =
      Map.pop_lazy(attrs!, :stats_ok, fn -> Faker.random_between(0, 10) end)

    {stats_rescued, attrs!} =
      Map.pop_lazy(attrs!, :stats_rescued, fn -> Faker.random_between(0, 10) end)

    {stats_skipped, attrs!} =
      Map.pop_lazy(attrs!, :stats_skipped, fn -> Faker.random_between(0, 10) end)

    {stats_unreachable, attrs!} =
      Map.pop_lazy(attrs!, :stats_unreachable, fn -> Faker.random_between(0, 10) end)

    {created_at, attrs!} = pop_entity_created_at(attrs!)
    {updated_at, attrs!} = pop_entity_updated_at(attrs!, created_at)

    [] = Map.keys(attrs!)

    %AnsiblePlaybookRun{
      id: id,
      playbook: playbook,
      playbook_path: playbook_path,
      playbook_digest: playbook_digest,
      git_revision: git_revision,
      host: host,
      port: port,
      user: user,
      vars: vars,
      vars_digest: vars_digest,
      server: server,
      server_id: server_id,
      state: state,
      started_at: started_at,
      finished_at: finished_at,
      exit_code: exit_code,
      number_of_events: number_of_events,
      last_event_at: last_event_at,
      stats_changed: stats_changed,
      stats_failures: stats_failures,
      stats_ignored: stats_ignored,
      stats_ok: stats_ok,
      stats_rescued: stats_rescued,
      stats_skipped: stats_skipped,
      stats_unreachable: stats_unreachable,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  @spec ansible_playbook_run_state() :: Types.ansible_playbook_run_state()
  def ansible_playbook_run_state,
    do: Enum.random([:pending, :running, :succeeded, :failed, :interrupted, :timeout])

  @spec ansible_playbook_run_failed_state() :: Types.ansible_playbook_run_failed_state()
  def ansible_playbook_run_failed_state,
    do: Enum.random(@failed_ansible_playbook_run_states)

  @spec random_connection_failure_reason() :: :timeout | :econnrefused | String.t()
  def random_connection_failure_reason do
    case Enum.random([:timeout, :econnrefused, :text]) do
      :text -> Faker.Lorem.sentence()
      reason -> reason
    end
  end

  @spec random_connection_state() :: ServerConnectionState.connection_state()
  def random_connection_state,
    do:
      [
        &__MODULE__.random_not_connected_state/0,
        &__MODULE__.random_connection_pending_state/0,
        &__MODULE__.random_connecting_state/0,
        &__MODULE__.random_connected_state/0,
        &__MODULE__.random_retry_connecting_state/0,
        &__MODULE__.random_reconnecting_state/0,
        &__MODULE__.random_connection_failed_state/0,
        &__MODULE__.random_disconnected_state/0
      ]
      |> Enum.random()
      |> apply([])

  @spec random_not_connected_state() :: ServerConnectionState.not_connected_state()
  @spec random_not_connected_state(map()) :: ServerConnectionState.not_connected_state()
  def random_not_connected_state(attrs! \\ %{}) do
    {connection_pid, attrs!} =
      Map.pop_lazy(attrs!, :connection_pid, fn ->
        if bool(), do: self(), else: nil
      end)

    [] = Map.keys(attrs!)

    not_connected_state(connection_pid: connection_pid)
  end

  @spec random_connection_pending_state() :: ServerConnectionState.connection_pending_state()
  @spec random_connection_pending_state(map()) :: ServerConnectionState.connection_pending_state()
  def random_connection_pending_state(attrs! \\ %{}) do
    {causation_event, attrs!} =
      Map.pop_lazy(attrs!, :causation_event, fn ->
        if bool() do
          EventsFactory.build(:event_reference)
        else
          nil
        end
      end)

    [] = Map.keys(attrs!)

    connection_pending_state(connection_pid: self(), causation_event: causation_event)
  end

  @spec random_connecting_state(map()) :: ServerConnectionState.connecting_state()
  def random_connecting_state(attrs! \\ %{}) do
    {retrying, attrs!} =
      case Map.pop_lazy(attrs!, :retrying, &bool/0) do
        {true, attrs} -> {random_retry(), attrs}
        {false, attrs} -> {false, attrs}
        {retry, attrs} when is_map(retry) -> {random_retry(retry), attrs}
      end

    {causation_event, attrs!} =
      Map.pop_lazy(attrs!, :causation_event, fn ->
        if bool() do
          EventsFactory.build(:event_reference)
        else
          nil
        end
      end)

    [] = Map.keys(attrs!)

    connecting_state(
      connection_ref: make_ref(),
      connection_pid: self(),
      time: Faker.DateTime.backward(1),
      retrying: retrying,
      causation_event: causation_event
    )
  end

  @spec random_retry_connecting_state() :: ServerConnectionState.retry_connecting_state()
  def random_retry_connecting_state,
    do: retry_connecting_state(connection_pid: self(), retrying: random_retry())

  @spec random_connected_state() :: ServerConnectionState.connected_state()
  @spec random_connected_state(Keyword.t()) :: ServerConnectionState.connected_state()
  def random_connected_state(attrs! \\ []) do
    {connection_event, attrs!} =
      Keyword.pop_lazy(attrs!, :connection_event, fn -> EventsFactory.build(:event_reference) end)

    {retry_event, attrs!} = Keyword.pop(attrs!, :retry_event, nil)

    [] = Keyword.keys(attrs!)

    connected_state(
      connection_ref: make_ref(),
      connection_pid: self(),
      time: Faker.DateTime.backward(1),
      connection_event: connection_event,
      retry_event: retry_event
    )
  end

  @spec random_reconnecting_state() :: ServerConnectionState.reconnecting_state()
  @spec random_reconnecting_state(Keyword.t()) :: ServerConnectionState.reconnecting_state()
  def random_reconnecting_state(attrs! \\ []) do
    {causation_event, attrs!} =
      Keyword.pop_lazy(attrs!, :causation_event, fn -> EventsFactory.build(:event_reference) end)

    [] = Keyword.keys(attrs!)

    reconnecting_state(
      connection_ref: make_ref(),
      connection_pid: self(),
      time: Faker.DateTime.backward(1),
      causation_event: causation_event
    )
  end

  @spec random_connection_failed_state() :: ServerConnectionState.connection_failed_state()
  def random_connection_failed_state,
    do: connection_failed_state(connection_pid: self(), reason: Faker.Lorem.sentence())

  @spec random_disconnected_state() :: ServerConnectionState.disconnected_state()
  def random_disconnected_state, do: disconnected_state(time: Faker.DateTime.backward(2))

  @spec random_retry(map) :: ServerConnectionState.retry()
  def random_retry(attrs! \\ %{}) do
    {retry, attrs!} = Map.pop_lazy(attrs!, :retry, fn -> Faker.random_between(1, 100) end)
    {backoff, attrs!} = Map.pop_lazy(attrs!, :backoff, fn -> Faker.random_between(1, 20) end)

    [] = Map.keys(attrs!)

    %{
      retry: retry,
      backoff: backoff,
      time: Faker.DateTime.backward(2),
      in_seconds: Faker.random_between(1, 86_000),
      reason: Faker.Lorem.sentence()
    }
  end

  @spec server_ansible_playbook_failed_problem(Keyword.t()) ::
          Types.server_ansible_playbook_failed_problem()
  def server_ansible_playbook_failed_problem(attrs! \\ []) do
    {playbook_run, attrs!} = Keyword.pop(attrs!, :playbook_run, nil)

    {playbook_name, attrs!} =
      Keyword.pop_lazy(attrs!, :playbook, fn ->
        case playbook_run do
          nil -> Faker.Lorem.word()
          run -> run.playbook
        end
      end)

    playbook_state =
      case get_in(playbook_run.state) do
        state when state in @failed_ansible_playbook_run_states -> state
        _non_failed_state -> Enum.random(@failed_ansible_playbook_run_states)
      end

    {playbook_stats, attrs!} =
      Keyword.pop_lazy(attrs!, :stats, fn ->
        case playbook_run do
          nil ->
            %{
              changed: Faker.random_between(0, 10),
              failures: Faker.random_between(0, 10),
              ignored: Faker.random_between(0, 10),
              ok: Faker.random_between(0, 10),
              rescued: Faker.random_between(0, 10),
              skipped: Faker.random_between(0, 10),
              unreachable: Faker.random_between(0, 10)
            }

          run ->
            %{
              changed: run.stats_changed,
              failures: run.stats_failures,
              ignored: run.stats_ignored,
              ok: run.stats_ok,
              rescued: run.stats_rescued,
              skipped: run.stats_skipped,
              unreachable: run.stats_unreachable
            }
        end
      end)

    [] = attrs!

    {:server_ansible_playbook_failed, playbook_name, playbook_state, playbook_stats}
  end

  @spec server_authentication_failed_problem :: Types.server_authentication_failed_problem()
  def server_authentication_failed_problem,
    do:
      {:server_authentication_failed, Enum.random([:username, :app_username]),
       Faker.Internet.user_name()}

  @spec server_connection_refused_problem :: Types.server_connection_refused_problem()
  def server_connection_refused_problem,
    do:
      {:server_connection_refused, NetFactory.ip_address(), NetFactory.port(),
       Faker.Internet.user_name()}

  @spec server_connection_timed_out_problem :: Types.server_connection_timed_out_problem()
  def server_connection_timed_out_problem,
    do:
      {:server_connection_timed_out, NetFactory.ip_address(), NetFactory.port(),
       Faker.Internet.user_name()}

  @spec server_expected_property_mismatch_problem ::
          Types.server_expected_property_mismatch_problem()
  def server_expected_property_mismatch_problem,
    do:
      {:server_expected_property_mismatch, Enum.random([:cpus, :cores, :vcpus, :memory, :swap]),
       Faker.random_between(1, 16), Faker.random_between(17, 32)}

  @spec server_fact_gathering_failed_problem :: Types.server_fact_gathering_failed_problem()
  def server_fact_gathering_failed_problem,
    do: {:server_fact_gathering_failed, Faker.Lorem.sentence()}

  @spec server_key_exchange_failed_problem() :: Types.server_key_exchange_failed_problem()
  def server_key_exchange_failed_problem,
    do:
      {:server_key_exchange_failed,
       optional(&SSHFactory.random_ssh_host_key_fingerprint_digest/0),
       1
       |> Range.new(Faker.random_between(1, 3))
       |> Enum.map_join("\n", fn _n -> SSHFactory.random_ssh_host_key_fingerprint_string() end)}

  @spec server_missing_sudo_access_problem :: Types.server_missing_sudo_access_problem()
  def server_missing_sudo_access_problem,
    do: {:server_missing_sudo_access, Faker.Internet.user_name(), Faker.Lorem.sentence()}

  @spec server_open_ports_check_failed_problem :: Types.server_open_ports_check_failed_problem()
  def server_open_ports_check_failed_problem,
    do:
      {:server_open_ports_check_failed,
       1
       |> Range.new(Faker.random_between(1, 3))
       |> Enum.map(fn _n -> {NetFactory.port(), Faker.Lorem.sentence()} end)}

  @spec server_port_testing_script_failed_problem ::
          Types.server_port_testing_script_failed_problem()
  def server_port_testing_script_failed_problem do
    case Enum.random([:error, :exit]) do
      :error ->
        {:server_port_testing_script_failed, {:error, Faker.Lorem.sentence()}}

      :exit ->
        {:server_port_testing_script_failed,
         {:exit, Faker.random_between(1, 255), Faker.Lorem.sentence()}}
    end
  end

  @spec server_reconnection_failed_problem :: Types.server_reconnection_failed_problem()
  def server_reconnection_failed_problem,
    do: {:server_reconnection_failed, Faker.Lorem.sentence()}

  @spec server_sudo_access_check_failed_problem :: Types.server_sudo_access_check_failed_problem()
  def server_sudo_access_check_failed_problem,
    do: {:server_sudo_access_check_failed, Faker.Internet.user_name(), Faker.Lorem.sentence()}

  @spec server_group_factory(map()) :: ServerGroup.t()
  def server_group_factory(attrs!) do
    {id, attrs!} = pop_entity_id(attrs!)

    {name, attrs!} =
      Map.pop_lazy(attrs!, :name, fn -> sequence(:server_group_name, &"Server group #{&1}") end)

    {start_date, attrs!} =
      Map.pop_lazy(attrs!, :start_date, optionally(fn -> Faker.Date.backward(100) end))

    {end_date, attrs!} =
      Map.pop_lazy(attrs!, :end_date, optionally(fn -> Faker.Date.forward(100) end))

    {active, attrs!} = Map.pop_lazy(attrs!, :active, &bool/0)
    {servers_enabled, attrs!} = Map.pop_lazy(attrs!, :servers_enabled, &bool/0)

    {expected_server_properties, attrs!} =
      Map.pop_lazy(attrs!, :expected_server_properties, fn ->
        build(:server_properties, id: id)
      end)

    {expected_server_properties_id, attrs!} =
      Map.pop_lazy(attrs!, :expected_server_properties_id, fn -> expected_server_properties.id end)

    {version, created_at, updated_at, attrs!} = pop_entity_version_and_timestamps(attrs!)

    [] = Map.keys(attrs!)

    %ServerGroup{
      id: id,
      name: name,
      start_date: start_date,
      end_date: end_date,
      active: active,
      servers_enabled: servers_enabled,
      expected_server_properties: expected_server_properties,
      expected_server_properties_id: expected_server_properties_id,
      version: version,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  @spec server_group_member_factory(map()) :: ServerGroupMember.t()
  def server_group_member_factory(attrs!) do
    {id, attrs!} = pop_entity_id(attrs!)
    {name, attrs!} = Map.pop_lazy(attrs!, :name, &Faker.Person.name/0)

    {username, attrs!} =
      Map.pop_lazy(attrs!, :username, fn ->
        sequence(:server_group_member_username, &"user#{&1}")
      end)

    {username_confirmed, attrs!} = Map.pop_lazy(attrs!, :username_confirmed, &bool/0)

    {domain, attrs!} =
      Map.pop_lazy(attrs!, :domain, fn ->
        sequence(:server_group_member_domain, &"domain#{&1}.archidep.ch")
      end)

    {active, attrs!} = Map.pop_lazy(attrs!, :active, &bool/0)
    {servers_enabled, attrs!} = Map.pop_lazy(attrs!, :servers_enabled, &bool/0)

    {group, attrs!} = Map.pop_lazy(attrs!, :group, fn -> build(:server_group) end)

    {group_id, attrs!} =
      Map.pop_lazy(attrs!, :group_id, fn ->
        case group do
          %ServerGroup{} -> group.id
          nil -> nil
          _not_loaded -> UUID.generate()
        end
      end)

    {owner, attrs!} = Map.pop_lazy(attrs!, :owner, optionally(fn -> build(:server_owner) end))

    {owner_id, attrs!} =
      Map.pop_lazy(attrs!, :owner_id, fn ->
        case owner do
          %ServerOwner{} -> owner.id
          nil -> nil
          _not_loaded -> UUID.generate()
        end
      end)

    {version, created_at, updated_at, attrs!} = pop_entity_version_and_timestamps(attrs!)

    [] = Map.keys(attrs!)

    %ServerGroupMember{
      id: id,
      name: name,
      username: username,
      username_confirmed: username_confirmed,
      domain: domain,
      active: active,
      servers_enabled: servers_enabled,
      group: group,
      group_id: group_id,
      owner: owner,
      owner_id: owner_id,
      version: version,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  @spec server_factory(map()) :: Server.t()
  def server_factory(attrs!) do
    {id, attrs!} = pop_entity_id(attrs!)

    {name, attrs!} =
      Map.pop_lazy(
        attrs!,
        :name,
        optionally(fn ->
          sequence(:class_name, &"Server #{&1}")
        end)
      )

    {ip_address, attrs!} =
      Map.pop_lazy(attrs!, :ip_address, &NetFactory.postgrex_inet/0)

    {username, attrs!} =
      Map.pop_lazy(attrs!, :username, fn -> sequence(:server_username, &"user#{&1}") end)

    {app_username, attrs!} =
      Map.pop_lazy(attrs!, :app_username, fn ->
        sequence(:server_app_username, &"appuser#{&1}")
      end)

    {ssh_port, attrs!} =
      case Map.pop_lazy(attrs!, :ssh_port, optionally(&NetFactory.port/0)) do
        {nil, attrs} -> {nil, attrs}
        {true, attrs} -> {NetFactory.port(), attrs}
        {port, attrs} when is_integer(port) and port > 0 and port < 65_536 -> {port, attrs}
      end

    {ssh_host_key_fingerprints, attrs!} =
      Map.pop_lazy(attrs!, :ssh_host_key_fingerprints, fn ->
        1
        |> Range.new(Faker.random_between(1, 3))
        |> Enum.map_join("\n", fn _n -> SSHFactory.random_ssh_host_key_fingerprint_string() end)
      end)

    {secret_key, attrs!} =
      Map.pop_lazy(attrs!, :secret_key, fn -> Faker.random_bytes(20) end)

    {active, attrs!} = Map.pop_lazy(attrs!, :active, &bool/0)
    {group, attrs!} = Map.pop(attrs!, :group, not_loaded(:group, Server))
    {group_id, attrs!} = Map.pop_lazy(attrs!, :group_id, &UUID.generate/0)
    {owner, attrs!} = Map.pop(attrs!, :owner, not_loaded(:owner, ServerOwner))
    {owner_id, attrs!} = Map.pop_lazy(attrs!, :owner_id, &UUID.generate/0)

    {expected_properties, attrs!} =
      Map.pop_lazy(attrs!, :expected_properties, fn ->
        build(:server_properties, id: id)
      end)

    {last_known_properties, attrs!} =
      Map.pop_lazy(
        attrs!,
        :last_known_properties,
        optionally(fn ->
          build(:server_properties)
        end)
      )

    {version, created_at, updated_at, attrs!} = pop_entity_version_and_timestamps(attrs!)

    {set_up_at, attrs!} =
      case Map.pop_lazy(
             attrs!,
             :set_up_at,
             optionally(fn -> Faker.DateTime.between(created_at, updated_at) end)
           ) do
        {nil, attrs} -> {nil, attrs}
        {true, attrs} -> {Faker.DateTime.between(created_at, updated_at), attrs}
        {%DateTime{} = dt, attrs} -> {dt, attrs}
      end

    {open_ports_checked_at, attrs!} =
      pop_server_open_ports_checked_at(attrs!, created_at, updated_at)

    [] = Map.keys(attrs!)

    %Server{
      id: id,
      name: name,
      ip_address: ip_address,
      username: username,
      app_username: app_username,
      ssh_port: ssh_port,
      ssh_host_key_fingerprints: ssh_host_key_fingerprints,
      secret_key: secret_key,
      active: active,
      group: group,
      group_id: group_id,
      owner: owner,
      owner_id: owner_id,
      expected_properties: expected_properties,
      expected_properties_id: expected_properties.id,
      last_known_properties: last_known_properties,
      last_known_properties_id: last_known_properties && last_known_properties.id,
      version: version,
      created_at: created_at,
      set_up_at: set_up_at,
      open_ports_checked_at: open_ports_checked_at,
      updated_at: updated_at
    }
  end

  defp pop_server_open_ports_checked_at(attrs, created_at, updated_at) do
    case Map.pop(
           attrs,
           :open_ports_checked_at
         ) do
      {nil, new_attrs} -> {nil, new_attrs}
      {true, new_attrs} -> {Faker.DateTime.between(created_at, updated_at), new_attrs}
      {%DateTime{} = dt, new_attrs} -> {dt, new_attrs}
    end
  end

  @spec server_manager_state_factory(map()) :: ServerManagerState.t()
  def server_manager_state_factory(attrs!) do
    {connection_state, attrs!} =
      Map.pop_lazy(attrs!, :connection_state, &random_connection_state/0)

    {server, attrs!} = Map.pop_lazy(attrs!, :server, fn -> build(:server) end)
    {pipeline, attrs!} = Map.pop(attrs!, :pipeline, ArchiDep.Servers.Ansible.Pipeline)

    {username, attrs!} =
      Map.pop_lazy(attrs!, :username, fn ->
        if(bool(), do: server.username, else: server.app_username)
      end)

    {actions, attrs!} = Map.pop(attrs!, :actions, [])
    {tasks, attrs!} = Map.pop(attrs!, :tasks, %{})
    {ansible, attrs!} = Map.pop(attrs!, :ansible, nil)
    {problems, attrs!} = Map.pop(attrs!, :problems, [])
    {retry_timer, attrs!} = Map.pop(attrs!, :retry_timer, nil)
    {load_average_timer, attrs!} = Map.pop(attrs!, :load_average_timer, nil)
    {connection_timer, attrs!} = Map.pop(attrs!, :connection_timer, nil)
    {version, attrs!} = pop_entity_version(attrs!)

    [] = Map.keys(attrs!)

    %ServerManagerState{
      connection_state: connection_state,
      server: server,
      pipeline: pipeline,
      username: username,
      actions: actions,
      tasks: tasks,
      ansible: ansible,
      problems: problems,
      retry_timer: retry_timer,
      load_average_timer: load_average_timer,
      connection_timer: connection_timer,
      version: version
    }
  end

  @spec server_owner_factory(map()) :: ServerOwner.t()
  def server_owner_factory(attrs!) do
    {id, attrs!} = pop_entity_id(attrs!)
    {root, attrs!} = Map.pop_lazy(attrs!, :root, &bool/0)
    {active, attrs!} = Map.pop_lazy(attrs!, :active, &bool/0)

    {group_member, attrs!} =
      Map.pop_lazy(attrs!, :group_member, fn ->
        if root do
          nil
        else
          build(:server_group_member)
        end
      end)

    {group_member_id, attrs!} =
      Map.pop_lazy(attrs!, :group_member_id, fn ->
        case group_member do
          %ServerGroup{} -> group_member.id
          nil -> nil
          _not_loaded -> UUID.generate()
        end
      end)

    {server_count, attrs!} =
      Map.pop_lazy(attrs!, :server_count, fn -> Faker.random_between(0, 5) end)

    {server_count_lock, attrs!} =
      Map.pop_lazy(attrs!, :server_count_lock, fn -> Faker.random_between(1, 1000) end)

    {active_server_count, attrs!} =
      Map.pop_lazy(attrs!, :active_server_count, fn -> Faker.random_between(0, server_count) end)

    {active_server_count_lock, attrs!} =
      Map.pop_lazy(attrs!, :active_server_count_lock, fn -> Faker.random_between(1, 1000) end)

    {version, created_at, updated_at, attrs!} = pop_entity_version_and_timestamps(attrs!)

    [] = Map.keys(attrs!)

    %ServerOwner{
      id: id,
      root: root,
      active: active,
      group_member: group_member,
      group_member_id: group_member_id,
      active_server_count: active_server_count,
      active_server_count_lock: active_server_count_lock,
      server_count: server_count,
      server_count_lock: server_count_lock,
      version: version,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  @spec server_properties_factory(map()) :: ServerProperties.t()
  def server_properties_factory(attrs!) do
    {id, attrs!} = pop_entity_id(attrs!)

    {hostname, attrs!} =
      Map.pop_lazy(attrs!, :hostname, optionally(&Faker.Internet.domain_name/0))

    {machine_id, attrs!} = Map.pop_lazy(attrs!, :machine_id, optionally(&Faker.String.base64/0))

    {cpus, attrs!} =
      Map.pop_lazy(attrs!, :cpus, optionally(fn -> Faker.random_between(1, 16) end))

    {cores, attrs!} =
      Map.pop_lazy(attrs!, :cores, optionally(fn -> Faker.random_between(1, 16) end))

    {vcpus, attrs!} =
      Map.pop_lazy(attrs!, :vcpus, optionally(fn -> Faker.random_between(1, 32) end))

    {memory, attrs!} =
      Map.pop_lazy(attrs!, :memory, optionally(fn -> Faker.random_between(1, 16) * 128 end))

    {swap, attrs!} =
      Map.pop_lazy(attrs!, :swap, optionally(fn -> Faker.random_between(1, 16) * 128 end))

    {system, attrs!} = Map.pop_lazy(attrs!, :system, optionally(&Faker.Company.buzzword/0))

    {architecture, attrs!} =
      Map.pop_lazy(attrs!, :architecture, optionally(&Faker.Company.buzzword/0))

    {os_family, attrs!} = Map.pop_lazy(attrs!, :os_family, optionally(&Faker.Company.buzzword/0))

    {distribution, attrs!} =
      Map.pop_lazy(attrs!, :distribution, optionally(&Faker.Company.buzzword/0))

    {distribution_release, attrs!} =
      Map.pop_lazy(attrs!, :distribution_release, &Faker.Company.buzzword/0)

    {distribution_version, attrs!} =
      Map.pop_lazy(attrs!, :distribution_version, &Faker.Company.buzzword/0)

    [] = Map.keys(attrs!)

    %ServerProperties{
      id: id,
      hostname: hostname,
      machine_id: machine_id,
      cpus: cpus,
      cores: cores,
      vcpus: vcpus,
      memory: memory,
      swap: swap,
      system: system,
      architecture: architecture,
      os_family: os_family,
      distribution: distribution,
      distribution_release: distribution_release,
      distribution_version: distribution_version
    }
  end

  @spec random_server_data() :: Types.server_data()
  @spec random_server_data(Keyword.t()) :: Types.server_data()
  def random_server_data(attrs! \\ []) do
    {name, attrs!} = Keyword.pop_lazy(attrs!, :name, optionally(&Faker.Person.name/0))

    {ip_address, attrs!} =
      Keyword.pop_lazy(attrs!, :ip_address, fn ->
        NetFactory.ip_address() |> :inet.ntoa() |> to_string()
      end)

    {username, attrs!} = Keyword.pop_lazy(attrs!, :username, &Faker.Internet.user_name/0)
    {ssh_port, attrs!} = Keyword.pop_lazy(attrs!, :ssh_port, &NetFactory.port/0)

    {ssh_host_key_fingerprints, attrs!} =
      Keyword.pop_lazy(attrs!, :ssh_host_key_fingerprints, fn ->
        1
        |> Range.new(Faker.random_between(1, 3))
        |> Enum.map_join("\n", fn _n -> SSHFactory.random_ssh_host_key_fingerprint_string() end)
      end)

    {active, attrs!} = Keyword.pop_lazy(attrs!, :active, &bool/0)
    {app_username, attrs!} = Keyword.pop_lazy(attrs!, :app_username, &Faker.Internet.user_name/0)

    {expected_properties, attrs!} =
      Keyword.pop_lazy(attrs!, :expected_properties, &random_server_properties/0)

    [] = Keyword.keys(attrs!)

    %{
      name: name,
      ip_address: ip_address,
      username: username,
      ssh_port: ssh_port,
      ssh_host_key_fingerprints: ssh_host_key_fingerprints,
      active: active,
      app_username: app_username,
      expected_properties: expected_properties
    }
  end

  @spec random_server_properties() :: Types.server_properties()
  @spec random_server_properties(map()) :: Types.server_properties()
  def random_server_properties(attrs! \\ %{}) do
    {hostname, attrs!} =
      Map.pop_lazy(attrs!, :hostname, optionally(&Faker.Internet.domain_name/0))

    {machine_id, attrs!} = Map.pop_lazy(attrs!, :machine_id, optionally(&Faker.String.base64/0))

    {cpus, attrs!} =
      Map.pop_lazy(attrs!, :cpus, optionally(fn -> Faker.random_between(1, 16) end))

    {cores, attrs!} =
      Map.pop_lazy(attrs!, :cores, optionally(fn -> Faker.random_between(1, 16) end))

    {vcpus, attrs!} =
      Map.pop_lazy(attrs!, :vcpus, optionally(fn -> Faker.random_between(1, 32) end))

    {memory, attrs!} =
      Map.pop_lazy(attrs!, :memory, optionally(fn -> Faker.random_between(1, 16) * 128 end))

    {swap, attrs!} =
      Map.pop_lazy(attrs!, :swap, optionally(fn -> Faker.random_between(1, 16) * 128 end))

    {system, attrs!} = Map.pop_lazy(attrs!, :system, optionally(&Faker.Company.buzzword/0))

    {architecture, attrs!} =
      Map.pop_lazy(attrs!, :architecture, optionally(&Faker.Company.buzzword/0))

    {os_family, attrs!} = Map.pop_lazy(attrs!, :os_family, optionally(&Faker.Company.buzzword/0))

    {distribution, attrs!} =
      Map.pop_lazy(attrs!, :distribution, optionally(&Faker.Company.buzzword/0))

    {distribution_release, attrs!} =
      Map.pop_lazy(attrs!, :distribution_release, &Faker.Company.buzzword/0)

    {distribution_version, attrs!} =
      Map.pop_lazy(attrs!, :distribution_version, &Faker.Company.buzzword/0)

    [] = Map.keys(attrs!)

    %{
      hostname: hostname,
      machine_id: machine_id,
      cpus: cpus,
      cores: cores,
      vcpus: vcpus,
      memory: memory,
      swap: swap,
      system: system,
      architecture: architecture,
      os_family: os_family,
      distribution: distribution,
      distribution_release: distribution_release,
      distribution_version: distribution_version
    }
  end

  @spec random_retry_connecting_cause :: :manual | :automated | {:event, EventReference.t()}
  def random_retry_connecting_cause,
    do: Enum.random([:manual, :automated, {:event, EventsFactory.build(:event_reference)}])
end
