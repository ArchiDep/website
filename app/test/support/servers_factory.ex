defmodule ArchiDep.Support.ServersFactory do
  @moduledoc """
  Test fixtures for the servers context.
  """

  use ArchiDep.Support, :factory

  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  alias ArchiDep.Servers.Ansible
  alias ArchiDep.Servers.Schemas.AnsiblePlaybook
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias ArchiDep.Servers.ServerTracking.ServerConnectionState
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Servers.Types
  alias ArchiDep.Support.NetFactory

  @playbooks [AnsiblePlaybook.name(Ansible.setup_playbook())]
  @finished_ansible_playbook_run_states [:succeeded, :failed, :interrupted, :timeout]

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

    {digest, attrs!} = Map.pop_lazy(attrs!, :digest, &Faker.String.base64/0)

    {git_revision, attrs!} =
      Map.pop_lazy(
        attrs!,
        :git_revision,
        fn -> sequence(:ansible_playbook_run_git_revision, &"rev-#{&1}") end
      )

    {host, attrs!} = Map.pop_lazy(attrs!, :host, &server_ip_address/0)
    {port, attrs!} = Map.pop_lazy(attrs!, :port, &NetFactory.port/0)

    {user, attrs!} =
      Map.pop_lazy(attrs!, :user, fn -> sequence(:ansible_playbook_run_user, &"user#{&1}") end)

    {vars, attrs!} =
      Map.pop_lazy(attrs!, :vars, fn ->
        %{"ansible_connection" => "ssh", "ansible_user" => user}
      end)

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
      Map.pop_lazy(attrs!, :started_at, fn ->
        DateTime.add(DateTime.utc_now(), -Faker.random_between(1, 300), :second)
      end)

    {finished_at, attrs!} =
      Map.pop_lazy(attrs!, :finished_at, fn ->
        if Enum.member?(@finished_ansible_playbook_run_states, state) do
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
      digest: digest,
      git_revision: git_revision,
      host: host,
      port: port,
      user: user,
      vars: vars,
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

  @spec random_connection_state() :: ServerConnectionState.connection_state()
  def random_connection_state,
    do:
      Enum.random([
        random_not_connected_state(),
        random_connecting_state(),
        random_connected_state(),
        random_reconnecting_state(),
        random_connection_failed_state(),
        random_disconnected_state()
      ])

  @spec random_not_connected_state() :: ServerConnectionState.not_connected_state()
  def random_not_connected_state, do: not_connected_state(connection_pid: self())

  @spec random_connecting_state(map()) :: ServerConnectionState.connecting_state()
  def random_connecting_state(attrs \\ %{}) do
    {retrying, attrs!} =
      Map.pop_lazy(attrs, :retrying, fn -> if(bool(), do: random_retry(), else: false) end)

    [] = Map.keys(attrs!)

    connecting_state(
      connection_ref: make_ref(),
      connection_pid: self(),
      retrying: retrying
    )
  end

  @spec random_retry_connecting_state() :: ServerConnectionState.retry_connecting_state()
  def random_retry_connecting_state,
    do: retry_connecting_state(connection_pid: self(), retrying: random_retry())

  @spec random_connected_state() :: ServerConnectionState.connected_state()
  def random_connected_state,
    do: connected_state(connection_ref: make_ref(), connection_pid: self())

  @spec random_reconnecting_state() :: ServerConnectionState.reconnecting_state()
  def random_reconnecting_state,
    do: reconnecting_state(connection_ref: make_ref(), connection_pid: self())

  @spec random_connection_failed_state() :: ServerConnectionState.connection_failed_state()
  def random_connection_failed_state,
    do: connection_failed_state(connection_pid: self(), reason: Faker.Lorem.sentence())

  @spec random_disconnected_state() :: ServerConnectionState.disconnected_state()
  def random_disconnected_state, do: disconnected_state(time: Faker.DateTime.backward(2))

  @spec random_retry :: ServerConnectionState.retry()
  def random_retry,
    do: %{
      retry: Faker.random_between(1, 100),
      backoff: Faker.random_between(1, 20),
      time: Faker.DateTime.backward(2),
      in_seconds: Faker.random_between(1, 86_000),
      reason: Faker.Lorem.sentence()
    }

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
      Map.pop_lazy(attrs!, :ip_address, &server_ip_address/0)

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

    [] = Map.keys(attrs!)

    %Server{
      id: id,
      name: name,
      ip_address: ip_address,
      username: username,
      app_username: app_username,
      ssh_port: ssh_port,
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
      updated_at: updated_at
    }
  end

  @spec server_ip_address() :: Postgrex.INET.t()
  def server_ip_address, do: %Postgrex.INET{address: NetFactory.ip_address(), netmask: nil}

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
    {ansible_playbook, attrs!} = Map.pop(attrs!, :ansible_playbook, nil)
    {problems, attrs!} = Map.pop(attrs!, :problems, [])
    {retry_timer, attrs!} = Map.pop(attrs!, :retry_timer, nil)
    {load_average_timer, attrs!} = Map.pop(attrs!, :load_average_timer, nil)
    {version, attrs!} = pop_entity_version(attrs!)

    [] = Map.keys(attrs!)

    %ServerManagerState{
      connection_state: connection_state,
      server: server,
      pipeline: pipeline,
      username: username,
      actions: actions,
      tasks: tasks,
      ansible_playbook: ansible_playbook,
      problems: problems,
      retry_timer: retry_timer,
      load_average_timer: load_average_timer,
      version: version
    }
  end

  @spec server_owner_factory(map()) :: ServerOwner.t()
  def server_owner_factory(attrs!) do
    {id, attrs!} = pop_entity_id(attrs!)
    {root, attrs!} = Map.pop_lazy(attrs!, :root, &bool/0)
    {active, attrs!} = Map.pop_lazy(attrs!, :active, &bool/0)

    {group_member, attrs!} =
      Map.pop_lazy(attrs!, :group_member, optionally(fn -> build(:server_group_member) end))

    {group_member_id, attrs!} =
      Map.pop_lazy(attrs!, :group_member_id, fn ->
        case group_member do
          %ServerGroup{} -> group_member.id
          nil -> nil
          _not_loaded -> UUID.generate()
        end
      end)

    {active_server_count, attrs!} =
      Map.pop_lazy(attrs!, :active_server_count, fn -> Faker.random_between(0, 5) end)

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
end
