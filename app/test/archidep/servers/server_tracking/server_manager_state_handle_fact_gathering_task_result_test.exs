defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateHandleFactGatheringTaskResultTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Support.ServerManagerStateTestUtils
  import ExUnit.CaptureLog
  import Hammox
  alias ArchiDep.Servers.Ansible
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias ArchiDep.Servers.ServerTracking.ServerManagerBehaviour
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.ServersFactory
  alias Phoenix.PubSub
  alias Phoenix.Token

  @pubsub ArchiDep.PubSub

  @no_server_properties [
    hostname: nil,
    machine_id: nil,
    cpus: nil,
    cores: nil,
    vcpus: nil,
    memory: nil,
    swap: nil,
    system: nil,
    architecture: nil,
    os_family: nil,
    distribution: nil,
    distribution_release: nil,
    distribution_version: nil
  ]

  setup :verify_on_exit!

  setup_all do
    %{
      handle_task_result:
        protect({ServerManagerState, :handle_task_result, 3}, ServerManagerBehaviour)
    }
  end

  test "run the port testing script after facts have been gathered",
       %{
         handle_task_result: handle_task_result
       } do
    server = insert_active_server!(set_up_at: true, ssh_port: true)
    server_secret_key = server.secret_key

    successful_run =
      ServersFactory.insert(:ansible_playbook_run,
        server: server,
        state: :succeeded,
        playbook_digest: Ansible.setup_playbook().digest
      )

    expect(Ansible.Mock, :digest_ansible_variables, fn %{"server_token" => ^server_secret_key} ->
      successful_run.vars_digest
    end)

    fake_gather_facts_ref = make_ref()
    fake_connection_event = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state:
          ServersFactory.random_connected_state(connection_event: fake_connection_event),
        server: server,
        username: server.app_username,
        tasks: %{gather_facts: fake_gather_facts_ref}
      )

    :ok = PubSub.subscribe(@pubsub, "servers:#{server.id}")
    :ok = PubSub.subscribe(@pubsub, "server-groups:#{server.group_id}:servers")
    :ok = PubSub.subscribe(@pubsub, "server-owners:#{server.owner_id}:servers")

    now = DateTime.utc_now()

    result =
      handle_task_result.(
        initial_state,
        fake_gather_facts_ref,
        {:ok, %{}}
      )

    assert %{
             server:
               %Server{
                 last_known_properties: %ServerProperties{id: last_known_properties_id}
               } = updated_server,
             actions:
               [
                 {:demonitor, ^fake_gather_facts_ref},
                 {:run_command, run_command_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    [facts_event] = fetch_new_stored_events([fake_connection_event])

    assert_server_facts_gathered_event!(
      facts_event,
      updated_server,
      %{},
      now,
      fake_connection_event
    )

    assert result == %ServerManagerState{
             initial_state
             | server: %Server{
                 server
                 | last_known_properties: %ServerProperties{
                     __meta__: loaded(ServerProperties, "server_properties"),
                     id: last_known_properties_id
                   },
                   last_known_properties_id: last_known_properties_id,
                   updated_at: updated_server.updated_at,
                   version: server.version + 1
               },
               actions: actions,
               tasks: %{}
           }

    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}

    fake_task = Task.completed(:fake)

    run_command_result =
      run_command_fn.(result, fn "sudo /usr/local/sbin/test-ports 80 443 3000 3001", 10_000 ->
        fake_task
      end)

    assert run_command_result ==
             %ServerManagerState{result | tasks: %{test_ports: fake_task.ref}}

    assert update_tracking_fn.(run_command_result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                current_job: :checking_open_ports,
                version: result.version + 1
              ), %ServerManagerState{run_command_result | version: result.version + 1}}
  end

  test "the connection process is complete after facts have been gathered if open ports have already been checked",
       %{
         handle_task_result: handle_task_result
       } do
    server = insert_active_server!(set_up_at: true, open_ports_checked_at: true, ssh_port: true)
    server_secret_key = server.secret_key

    successful_run =
      ServersFactory.insert(:ansible_playbook_run,
        server: server,
        state: :succeeded,
        playbook_digest: Ansible.setup_playbook().digest
      )

    expect(Ansible.Mock, :digest_ansible_variables, fn %{"server_token" => ^server_secret_key} ->
      successful_run.vars_digest
    end)

    fake_gather_facts_ref = make_ref()
    fake_connection_event = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state:
          ServersFactory.random_connected_state(connection_event: fake_connection_event),
        server: server,
        username: server.app_username,
        tasks: %{gather_facts: fake_gather_facts_ref}
      )

    :ok = PubSub.subscribe(@pubsub, "servers:#{server.id}")
    :ok = PubSub.subscribe(@pubsub, "server-groups:#{server.group_id}:servers")
    :ok = PubSub.subscribe(@pubsub, "server-owners:#{server.owner_id}:servers")

    now = DateTime.utc_now()

    result =
      handle_task_result.(
        initial_state,
        fake_gather_facts_ref,
        {:ok, %{}}
      )

    assert %{
             server:
               %Server{
                 last_known_properties: %ServerProperties{id: last_known_properties_id}
               } = updated_server,
             actions:
               [
                 {:demonitor, ^fake_gather_facts_ref},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    [facts_event] = fetch_new_stored_events([fake_connection_event])

    assert_server_facts_gathered_event!(
      facts_event,
      updated_server,
      %{},
      now,
      fake_connection_event
    )

    assert result == %ServerManagerState{
             initial_state
             | server: %Server{
                 server
                 | last_known_properties: %ServerProperties{
                     __meta__: loaded(ServerProperties, "server_properties"),
                     id: last_known_properties_id
                   },
                   last_known_properties_id: last_known_properties_id,
                   updated_at: updated_server.updated_at,
                   version: server.version + 1
               },
               actions: actions,
               tasks: %{}
           }

    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "detected properties are saved after gathering facts the first time",
       %{
         handle_task_result: handle_task_result
       } do
    server =
      insert_active_server!(
        set_up_at: true,
        ssh_port: true,
        class_expected_server_properties: @no_server_properties,
        server_expected_properties: @no_server_properties
      )

    server_secret_key = server.secret_key

    successful_run =
      ServersFactory.insert(:ansible_playbook_run,
        server: server,
        state: :succeeded,
        playbook_digest: Ansible.setup_playbook().digest
      )

    expect(Ansible.Mock, :digest_ansible_variables, fn %{"server_token" => ^server_secret_key} ->
      successful_run.vars_digest
    end)

    fake_gather_facts_ref = make_ref()
    fake_connection_event = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state:
          ServersFactory.random_connected_state(connection_event: fake_connection_event),
        server: server,
        username: server.app_username,
        tasks: %{gather_facts: fake_gather_facts_ref}
      )

    :ok = PubSub.subscribe(@pubsub, "servers:#{server.id}")
    :ok = PubSub.subscribe(@pubsub, "server-groups:#{server.group_id}:servers")
    :ok = PubSub.subscribe(@pubsub, "server-owners:#{server.owner_id}:servers")

    fake_facts = %{
      "ansible_hostname" => "test-server",
      "ansible_machine_id" => "1234567890abcdef",
      "ansible_processor_count" => 2,
      "ansible_processor_cores" => 4,
      "ansible_processor_vcpus" => 8,
      "ansible_memory_mb" => %{
        "real" => %{"total" => 4096},
        "swap" => %{"total" => 2048}
      },
      "ansible_system" => "Linux",
      "ansible_architecture" => "x86_64",
      "ansible_os_family" => "Debian",
      "ansible_distribution" => "Ubuntu",
      "ansible_distribution_release" => "noble",
      "ansible_distribution_version" => "24.04"
    }

    now = DateTime.utc_now()

    result =
      handle_task_result.(
        initial_state,
        fake_gather_facts_ref,
        {:ok, fake_facts}
      )

    assert %{
             server:
               %Server{
                 last_known_properties: %ServerProperties{id: last_known_properties_id}
               } = updated_server,
             actions:
               [
                 {:demonitor, ^fake_gather_facts_ref},
                 {:run_command, run_command_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    [facts_event] = fetch_new_stored_events([fake_connection_event])

    assert_server_facts_gathered_event!(
      facts_event,
      updated_server,
      fake_facts,
      now,
      fake_connection_event
    )

    assert result == %ServerManagerState{
             initial_state
             | server: %Server{
                 server
                 | last_known_properties: %ServerProperties{
                     __meta__: loaded(ServerProperties, "server_properties"),
                     id: last_known_properties_id,
                     hostname: "test-server",
                     machine_id: "1234567890abcdef",
                     cpus: 2,
                     cores: 4,
                     vcpus: 8,
                     memory: 4096,
                     swap: 2048,
                     system: "Linux",
                     architecture: "x86_64",
                     os_family: "Debian",
                     distribution: "Ubuntu",
                     distribution_release: "noble",
                     distribution_version: "24.04"
                   },
                   last_known_properties_id: last_known_properties_id,
                   updated_at: updated_server.updated_at,
                   version: server.version + 1
               },
               actions: actions,
               tasks: %{}
           }

    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}

    fake_task = Task.completed(:fake)

    run_command_result =
      run_command_fn.(result, fn "sudo /usr/local/sbin/test-ports 80 443 3000 3001", 10_000 ->
        fake_task
      end)

    assert run_command_result ==
             %ServerManagerState{result | tasks: %{test_ports: fake_task.ref}}

    assert update_tracking_fn.(run_command_result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                current_job: :checking_open_ports,
                version: result.version + 1
              ), %ServerManagerState{run_command_result | version: result.version + 1}}
  end

  test "last known server properties are updated after gathering facts",
       %{
         handle_task_result: handle_task_result
       } do
    server =
      insert_active_server!(
        set_up_at: true,
        ssh_port: true,
        class_expected_server_properties: @no_server_properties,
        server_expected_properties: @no_server_properties,
        server_last_known_properties: [
          hostname: "old-hostname",
          machine_id: "old-machine-id",
          cpus: 1,
          cores: 1,
          vcpus: nil,
          memory: 1024,
          swap: 512,
          system: "OldOS",
          architecture: "i386",
          os_family: "OldFamily",
          distribution: "OldDistro",
          distribution_release: nil,
          distribution_version: "0.1"
        ]
      )

    server_secret_key = server.secret_key

    successful_run =
      ServersFactory.insert(:ansible_playbook_run,
        server: server,
        state: :succeeded,
        playbook_digest: Ansible.setup_playbook().digest
      )

    expect(Ansible.Mock, :digest_ansible_variables, fn %{"server_token" => ^server_secret_key} ->
      successful_run.vars_digest
    end)

    fake_gather_facts_ref = make_ref()
    fake_connection_event = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state:
          ServersFactory.random_connected_state(connection_event: fake_connection_event),
        server: server,
        username: server.app_username,
        tasks: %{gather_facts: fake_gather_facts_ref}
      )

    :ok = PubSub.subscribe(@pubsub, "servers:#{server.id}")
    :ok = PubSub.subscribe(@pubsub, "server-groups:#{server.group_id}:servers")
    :ok = PubSub.subscribe(@pubsub, "server-owners:#{server.owner_id}:servers")

    fake_facts = %{
      "ansible_hostname" => "test-server",
      "ansible_machine_id" => "1234567890abcdef",
      "ansible_processor_count" => 2,
      "ansible_processor_cores" => 4,
      "ansible_processor_vcpus" => 8,
      "ansible_memory_mb" => %{
        "real" => %{"total" => 4096},
        "swap" => %{"total" => 2048}
      },
      "ansible_system" => "Linux",
      "ansible_architecture" => "x86_64",
      "ansible_os_family" => "Debian",
      "ansible_distribution" => "Ubuntu",
      "ansible_distribution_release" => "noble",
      "ansible_distribution_version" => "24.04"
    }

    now = DateTime.utc_now()

    result =
      handle_task_result.(
        initial_state,
        fake_gather_facts_ref,
        {:ok, fake_facts}
      )

    assert %{
             server: updated_server,
             actions:
               [
                 {:demonitor, ^fake_gather_facts_ref},
                 {:run_command, run_command_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    [facts_event] = fetch_new_stored_events([fake_connection_event])

    assert_server_facts_gathered_event!(
      facts_event,
      updated_server,
      fake_facts,
      now,
      fake_connection_event
    )

    assert result == %ServerManagerState{
             initial_state
             | server: %Server{
                 server
                 | last_known_properties: %ServerProperties{
                     __meta__: loaded(ServerProperties, "server_properties"),
                     id: server.last_known_properties_id,
                     hostname: "test-server",
                     machine_id: "1234567890abcdef",
                     cpus: 2,
                     cores: 4,
                     vcpus: 8,
                     memory: 4096,
                     swap: 2048,
                     system: "Linux",
                     architecture: "x86_64",
                     os_family: "Debian",
                     distribution: "Ubuntu",
                     distribution_release: "noble",
                     distribution_version: "24.04"
                   },
                   last_known_properties_id: server.last_known_properties_id,
                   updated_at: updated_server.updated_at,
                   version: server.version + 1
               },
               actions: actions,
               tasks: %{}
           }

    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}

    fake_task = Task.completed(:fake)

    run_command_result =
      run_command_fn.(result, fn "sudo /usr/local/sbin/test-ports 80 443 3000 3001", 10_000 ->
        fake_task
      end)

    assert run_command_result ==
             %ServerManagerState{result | tasks: %{test_ports: fake_task.ref}}

    assert update_tracking_fn.(run_command_result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                current_job: :checking_open_ports,
                version: result.version + 1
              ), %ServerManagerState{run_command_result | version: result.version + 1}}
  end

  test "server property mismatches are detected after gathering facts",
       %{
         handle_task_result: handle_task_result
       } do
    server =
      insert_active_server!(
        set_up_at: true,
        ssh_port: true,
        class_expected_server_properties: [
          hostname: nil,
          machine_id: nil,
          cpus: 4,
          cores: 8,
          vcpus: nil,
          memory: 2048,
          swap: nil,
          system: "Windows",
          architecture: "x86_64",
          os_family: nil,
          distribution: nil,
          distribution_release: "bar",
          distribution_version: "0.01"
        ],
        server_expected_properties: [
          hostname: nil,
          machine_id: nil,
          cpus: 2,
          cores: nil,
          vcpus: 8,
          memory: nil,
          swap: 4096,
          system: "Linux",
          architecture: nil,
          os_family: "Debian",
          distribution: "Foo",
          distribution_release: nil,
          distribution_version: "0.02"
        ]
      )

    server_secret_key = server.secret_key

    successful_run =
      ServersFactory.insert(:ansible_playbook_run,
        server: server,
        state: :succeeded,
        playbook_digest: Ansible.setup_playbook().digest
      )

    expect(Ansible.Mock, :digest_ansible_variables, fn %{"server_token" => ^server_secret_key} ->
      successful_run.vars_digest
    end)

    fake_gather_facts_ref = make_ref()
    fake_connection_event = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state:
          ServersFactory.random_connected_state(connection_event: fake_connection_event),
        server: server,
        username: server.app_username,
        tasks: %{gather_facts: fake_gather_facts_ref},
        problems: [
          ServersFactory.server_expected_property_mismatch_problem(),
          ServersFactory.server_expected_property_mismatch_problem()
        ]
      )

    :ok = PubSub.subscribe(@pubsub, "servers:#{server.id}")
    :ok = PubSub.subscribe(@pubsub, "server-groups:#{server.group_id}:servers")
    :ok = PubSub.subscribe(@pubsub, "server-owners:#{server.owner_id}:servers")

    fake_facts = %{
      "ansible_hostname" => "test-server",
      "ansible_machine_id" => "1234567890abcdef",
      "ansible_processor_count" => 4,
      "ansible_processor_cores" => 7,
      "ansible_processor_vcpus" => 9,
      "ansible_memory_mb" => %{
        "real" => %{"total" => 2000},
        "swap" => %{"total" => 4096}
      },
      "ansible_system" => "macOS",
      "ansible_architecture" => "arm64",
      "ansible_os_family" => "DOS"
    }

    now = DateTime.utc_now()

    result =
      handle_task_result.(
        initial_state,
        fake_gather_facts_ref,
        {:ok, fake_facts}
      )

    assert %{
             server: %Server{last_known_properties_id: last_known_properties_id} = updated_server,
             actions:
               [
                 {:demonitor, ^fake_gather_facts_ref},
                 {:run_command, run_command_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    [facts_event] = fetch_new_stored_events([fake_connection_event])

    assert_server_facts_gathered_event!(
      facts_event,
      updated_server,
      fake_facts,
      now,
      fake_connection_event
    )

    assert result == %ServerManagerState{
             initial_state
             | server: %Server{
                 server
                 | last_known_properties: %ServerProperties{
                     __meta__: loaded(ServerProperties, "server_properties"),
                     id: last_known_properties_id,
                     hostname: "test-server",
                     machine_id: "1234567890abcdef",
                     cpus: 4,
                     cores: 7,
                     vcpus: 9,
                     memory: 2000,
                     swap: 4096,
                     system: "macOS",
                     architecture: "arm64",
                     os_family: "DOS"
                   },
                   last_known_properties_id: last_known_properties_id,
                   updated_at: updated_server.updated_at,
                   version: server.version + 1
               },
               actions: actions,
               tasks: %{},
               problems: [
                 {:server_expected_property_mismatch, :cpus, 2, 4},
                 {:server_expected_property_mismatch, :cores, 8, 7},
                 {:server_expected_property_mismatch, :vcpus, 8, 9},
                 {:server_expected_property_mismatch, :system, "Linux", "macOS"},
                 {:server_expected_property_mismatch, :architecture, "x86_64", "arm64"},
                 {:server_expected_property_mismatch, :os_family, "Debian", "DOS"}
               ]
           }

    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}

    fake_task = Task.completed(:fake)

    run_command_result =
      run_command_fn.(result, fn "sudo /usr/local/sbin/test-ports 80 443 3000 3001", 10_000 ->
        fake_task
      end)

    assert run_command_result ==
             %ServerManagerState{result | tasks: %{test_ports: fake_task.ref}}

    assert update_tracking_fn.(run_command_result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                current_job: :checking_open_ports,
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{run_command_result | version: result.version + 1}}
  end

  test "a warning is logged if no previous ansible setup playbook run is found after gathering facts",
       %{
         handle_task_result: handle_task_result
       } do
    server = insert_active_server!(set_up_at: true, ssh_port: true)

    fake_gather_facts_ref = make_ref()
    fake_connection_event = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state:
          ServersFactory.random_connected_state(connection_event: fake_connection_event),
        server: server,
        username: server.app_username,
        tasks: %{gather_facts: fake_gather_facts_ref}
      )

    :ok = PubSub.subscribe(@pubsub, "servers:#{server.id}")
    :ok = PubSub.subscribe(@pubsub, "server-groups:#{server.group_id}:servers")
    :ok = PubSub.subscribe(@pubsub, "server-owners:#{server.owner_id}:servers")

    now = DateTime.utc_now()

    {result, log} =
      with_log(fn ->
        handle_task_result.(
          initial_state,
          fake_gather_facts_ref,
          {:ok, %{}}
        )
      end)

    assert log =~ "No previous Ansible setup playbook run found for server #{server.id}"

    assert %{
             server:
               %Server{
                 last_known_properties: %ServerProperties{id: last_known_properties_id}
               } = updated_server,
             actions:
               [
                 {:demonitor, ^fake_gather_facts_ref},
                 {:run_command, run_command_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    [facts_event] = fetch_new_stored_events([fake_connection_event])

    assert_server_facts_gathered_event!(
      facts_event,
      updated_server,
      %{},
      now,
      fake_connection_event
    )

    assert result == %ServerManagerState{
             initial_state
             | server: %Server{
                 server
                 | last_known_properties: %ServerProperties{
                     __meta__: loaded(ServerProperties, "server_properties"),
                     id: last_known_properties_id
                   },
                   last_known_properties_id: last_known_properties_id,
                   updated_at: updated_server.updated_at,
                   version: server.version + 1
               },
               actions: actions,
               tasks: %{}
           }

    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}

    fake_task = Task.completed(:fake)

    run_command_result =
      run_command_fn.(result, fn "sudo /usr/local/sbin/test-ports 80 443 3000 3001", 10_000 ->
        fake_task
      end)

    assert run_command_result ==
             %ServerManagerState{result | tasks: %{test_ports: fake_task.ref}}

    assert update_tracking_fn.(run_command_result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                current_job: :checking_open_ports,
                version: result.version + 1
              ), %ServerManagerState{run_command_result | version: result.version + 1}}
  end

  test "the setup playbook is rerun after gathering facts if the previous run failed",
       %{
         handle_task_result: handle_task_result
       } do
    server = insert_active_server!(set_up_at: true, ssh_port: true)
    server_secret_key = server.secret_key

    ServersFactory.insert(:ansible_playbook_run,
      server: server,
      state: :failed,
      playbook_digest: Ansible.setup_playbook().digest
    )

    expect(Ansible.Mock, :digest_ansible_variables, fn %{"server_token" => ^server_secret_key} ->
      Faker.random_bytes(10)
    end)

    fake_gather_facts_ref = make_ref()
    fake_connection_event = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state:
          ServersFactory.random_connected_state(connection_event: fake_connection_event),
        server: server,
        username: server.app_username,
        tasks: %{gather_facts: fake_gather_facts_ref}
      )

    :ok = PubSub.subscribe(@pubsub, "servers:#{server.id}")
    :ok = PubSub.subscribe(@pubsub, "server-groups:#{server.group_id}:servers")
    :ok = PubSub.subscribe(@pubsub, "server-owners:#{server.owner_id}:servers")

    now = DateTime.utc_now()

    result =
      handle_task_result.(
        initial_state,
        fake_gather_facts_ref,
        {:ok, %{}}
      )

    assert %{
             server:
               %Server{
                 last_known_properties: %ServerProperties{id: last_known_properties_id}
               } = updated_server,
             actions:
               [
                 {:demonitor, ^fake_gather_facts_ref},
                 {:run_playbook,
                  %{
                    git_revision: git_revision,
                    vars: %{"server_token" => server_token},
                    vars_digest: vars_digest,
                    created_at: playbook_created_at
                  } =
                    playbook_run, playbook_run_cause},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    [facts_event, run_started_event] = fetch_new_stored_events([fake_connection_event])

    assert_server_facts_gathered_event!(
      facts_event,
      updated_server,
      %{},
      now,
      fake_connection_event
    )

    run_started_event_ref =
      assert_ansible_playbook_run_started_event!(
        run_started_event,
        playbook_run,
        now,
        fake_connection_event
      )

    assert playbook_run_cause == run_started_event_ref

    assert result == %ServerManagerState{
             initial_state
             | server: %Server{
                 server
                 | last_known_properties: %ServerProperties{
                     __meta__: loaded(ServerProperties, "server_properties"),
                     id: last_known_properties_id
                   },
                   last_known_properties_id: last_known_properties_id,
                   updated_at: updated_server.updated_at,
                   version: server.version + 1
               },
               ansible_playbook: {playbook_run, nil, fake_connection_event},
               actions: actions,
               tasks: %{}
           }

    assert_in_delta DateTime.diff(now, playbook_created_at, :second), 0, 1

    assert playbook_run == %AnsiblePlaybookRun{
             __meta__: loaded(AnsiblePlaybookRun, "ansible_playbook_runs"),
             id: playbook_run.id,
             playbook: "setup",
             playbook_path: "priv/ansible/playbooks/setup.yml",
             playbook_digest: Ansible.setup_playbook().digest,
             git_revision: git_revision,
             host: server.ip_address,
             port: server.ssh_port,
             user: server.app_username,
             vars: %{
               "api_base_url" => "http://localhost:42000/api",
               "app_user_name" => server.app_username,
               "app_user_authorized_key" => ssh_public_key(),
               "server_id" => server.id,
               "server_token" => server_token
             },
             vars_digest: vars_digest,
             server: updated_server,
             server_id: server.id,
             state: :pending,
             started_at: nil,
             created_at: playbook_created_at,
             updated_at: playbook_created_at
           }

    server_id = server.id

    assert {:ok, ^server_id} =
             Token.verify(server.secret_key, "server auth", server_token, max_age: 5)

    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                current_job: {:running_playbook, playbook_run.playbook, playbook_run.id, nil},
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "the setup playbook is rerun after gathering facts if its digest has changed",
       %{
         handle_task_result: handle_task_result
       } do
    server = insert_active_server!(set_up_at: true, ssh_port: true)
    server_secret_key = server.secret_key

    successful_run =
      ServersFactory.insert(:ansible_playbook_run,
        server: server,
        state: :succeeded,
        playbook_digest: <<102, 111, 111>>
      )

    expect(Ansible.Mock, :digest_ansible_variables, fn %{"server_token" => ^server_secret_key} ->
      successful_run.vars_digest
    end)

    fake_gather_facts_ref = make_ref()
    fake_connection_event = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state:
          ServersFactory.random_connected_state(connection_event: fake_connection_event),
        server: server,
        username: server.app_username,
        tasks: %{gather_facts: fake_gather_facts_ref}
      )

    :ok = PubSub.subscribe(@pubsub, "servers:#{server.id}")
    :ok = PubSub.subscribe(@pubsub, "server-groups:#{server.group_id}:servers")
    :ok = PubSub.subscribe(@pubsub, "server-owners:#{server.owner_id}:servers")

    now = DateTime.utc_now()

    result =
      handle_task_result.(
        initial_state,
        fake_gather_facts_ref,
        {:ok, %{}}
      )

    assert %{
             server:
               %Server{
                 last_known_properties: %ServerProperties{id: last_known_properties_id}
               } = updated_server,
             actions:
               [
                 {:demonitor, ^fake_gather_facts_ref},
                 {:run_playbook,
                  %{
                    git_revision: git_revision,
                    vars: %{"server_token" => server_token},
                    vars_digest: vars_digest,
                    created_at: playbook_created_at
                  } =
                    playbook_run, playbook_run_cause},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    [facts_event, run_started_event] = fetch_new_stored_events([fake_connection_event])

    assert_server_facts_gathered_event!(
      facts_event,
      updated_server,
      %{},
      now,
      fake_connection_event
    )

    run_started_event_ref =
      assert_ansible_playbook_run_started_event!(
        run_started_event,
        playbook_run,
        now,
        fake_connection_event
      )

    assert playbook_run_cause == run_started_event_ref

    assert result == %ServerManagerState{
             initial_state
             | server: %Server{
                 server
                 | last_known_properties: %ServerProperties{
                     __meta__: loaded(ServerProperties, "server_properties"),
                     id: last_known_properties_id
                   },
                   last_known_properties_id: last_known_properties_id,
                   updated_at: updated_server.updated_at,
                   version: server.version + 1
               },
               ansible_playbook: {playbook_run, nil, fake_connection_event},
               actions: actions,
               tasks: %{}
           }

    assert_in_delta DateTime.diff(now, playbook_created_at, :second), 0, 1

    assert playbook_run == %AnsiblePlaybookRun{
             __meta__: loaded(AnsiblePlaybookRun, "ansible_playbook_runs"),
             id: playbook_run.id,
             playbook: "setup",
             playbook_path: "priv/ansible/playbooks/setup.yml",
             playbook_digest: Ansible.setup_playbook().digest,
             git_revision: git_revision,
             host: server.ip_address,
             port: server.ssh_port,
             user: server.app_username,
             vars: %{
               "api_base_url" => "http://localhost:42000/api",
               "app_user_name" => server.app_username,
               "app_user_authorized_key" => ssh_public_key(),
               "server_id" => server.id,
               "server_token" => server_token
             },
             vars_digest: vars_digest,
             server: updated_server,
             server_id: server.id,
             state: :pending,
             started_at: nil,
             created_at: playbook_created_at,
             updated_at: playbook_created_at
           }

    server_id = server.id

    assert {:ok, ^server_id} =
             Token.verify(server.secret_key, "server auth", server_token, max_age: 5)

    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                current_job: {:running_playbook, playbook_run.playbook, playbook_run.id, nil},
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "the setup playbook is rerun after gathering facts if the digest of its variables has changed",
       %{
         handle_task_result: handle_task_result
       } do
    server = insert_active_server!(set_up_at: true, ssh_port: true)
    server_secret_key = server.secret_key

    successful_run =
      ServersFactory.insert(:ansible_playbook_run,
        server: server,
        state: :succeeded,
        playbook_digest: Ansible.setup_playbook().digest
      )

    expect(Ansible.Mock, :digest_ansible_variables, fn %{"server_token" => ^server_secret_key} ->
      successful_run.vars_digest <> <<0>>
    end)

    fake_gather_facts_ref = make_ref()
    fake_connection_event = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state:
          ServersFactory.random_connected_state(connection_event: fake_connection_event),
        server: server,
        username: server.app_username,
        tasks: %{gather_facts: fake_gather_facts_ref}
      )

    :ok = PubSub.subscribe(@pubsub, "servers:#{server.id}")
    :ok = PubSub.subscribe(@pubsub, "server-groups:#{server.group_id}:servers")
    :ok = PubSub.subscribe(@pubsub, "server-owners:#{server.owner_id}:servers")

    now = DateTime.utc_now()

    result =
      handle_task_result.(
        initial_state,
        fake_gather_facts_ref,
        {:ok, %{}}
      )

    assert %{
             server:
               %Server{
                 last_known_properties: %ServerProperties{id: last_known_properties_id}
               } = updated_server,
             actions:
               [
                 {:demonitor, ^fake_gather_facts_ref},
                 {:run_playbook,
                  %{
                    git_revision: git_revision,
                    vars: %{"server_token" => server_token},
                    vars_digest: vars_digest,
                    created_at: playbook_created_at
                  } =
                    playbook_run, playbook_run_cause},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    [facts_event, run_started_event] = fetch_new_stored_events([fake_connection_event])

    assert_server_facts_gathered_event!(
      facts_event,
      updated_server,
      %{},
      now,
      fake_connection_event
    )

    run_started_event_ref =
      assert_ansible_playbook_run_started_event!(
        run_started_event,
        playbook_run,
        now,
        fake_connection_event
      )

    assert playbook_run_cause == run_started_event_ref

    assert result == %ServerManagerState{
             initial_state
             | server: %Server{
                 server
                 | last_known_properties: %ServerProperties{
                     __meta__: loaded(ServerProperties, "server_properties"),
                     id: last_known_properties_id
                   },
                   last_known_properties_id: last_known_properties_id,
                   updated_at: updated_server.updated_at,
                   version: server.version + 1
               },
               ansible_playbook: {playbook_run, nil, fake_connection_event},
               actions: actions,
               tasks: %{}
           }

    assert_in_delta DateTime.diff(now, playbook_created_at, :second), 0, 1

    assert playbook_run == %AnsiblePlaybookRun{
             __meta__: loaded(AnsiblePlaybookRun, "ansible_playbook_runs"),
             id: playbook_run.id,
             playbook: "setup",
             playbook_path: "priv/ansible/playbooks/setup.yml",
             playbook_digest: Ansible.setup_playbook().digest,
             git_revision: git_revision,
             host: server.ip_address,
             port: server.ssh_port,
             user: server.app_username,
             vars: %{
               "api_base_url" => "http://localhost:42000/api",
               "app_user_name" => server.app_username,
               "app_user_authorized_key" => ssh_public_key(),
               "server_id" => server.id,
               "server_token" => server_token
             },
             vars_digest: vars_digest,
             server: updated_server,
             server_id: server.id,
             state: :pending,
             started_at: nil,
             created_at: playbook_created_at,
             updated_at: playbook_created_at
           }

    server_id = server.id

    assert {:ok, ^server_id} =
             Token.verify(server.secret_key, "server auth", server_token, max_age: 5)

    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}
    assert_receive {:server_updated, ^updated_server}

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                current_job: {:running_playbook, playbook_run.playbook, playbook_run.id, nil},
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "a fact gathering error stops the connection process",
       %{
         handle_task_result: handle_task_result
       } do
    server = insert_active_server!(set_up_at: true, ssh_port: true)

    ServersFactory.insert(:ansible_playbook_run,
      server: server,
      state: :succeeded,
      playbook_digest: Ansible.setup_playbook().digest
    )

    fake_gather_facts_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        tasks: %{gather_facts: fake_gather_facts_ref}
      )

    fact_gathering_error = Faker.Lorem.sentence()

    {result, log} =
      with_log(fn ->
        handle_task_result.(
          initial_state,
          fake_gather_facts_ref,
          {:error, fact_gathering_error}
        )
      end)

    assert log =~ "Server manager could not gather facts for server #{server.id}"
    assert_no_stored_events!()

    assert %{
             actions:
               [
                 {:demonitor, ^fake_gather_facts_ref},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{},
               problems: [
                 {:server_fact_gathering_failed, fact_gathering_error}
               ]
           }

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  defp assert_server_facts_gathered_event!(
         %StoredEvent{id: event_id, occurred_at: occurred_at} = event,
         server,
         facts,
         now,
         caused_by
       ) do
    assert_in_delta DateTime.diff(now, occurred_at, :second), 0, 1

    assert event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "servers:servers:#{server.id}",
             version: server.version,
             type: "archidep/servers/server-facts-gathered",
             data: %{
               "id" => server.id,
               "name" => server.name,
               "ip_address" => server.ip_address.address |> :inet.ntoa() |> to_string(),
               "username" => server.username,
               "ssh_username" => server.app_username,
               "ssh_port" => server.ssh_port,
               "facts" => facts,
               "group" => %{
                 "id" => server.group.id,
                 "name" => server.group.name
               },
               "owner" => %{
                 "id" => server.owner.id,
                 "username" => server.owner.username,
                 "name" =>
                   if server.owner.group_member do
                     server.owner.group_member.name
                   else
                     nil
                   end,
                 "root" => server.owner.root
               }
             },
             meta: %{},
             initiator: "servers:servers:#{server.id}",
             causation_id: caused_by.id,
             correlation_id: caused_by.correlation_id,
             occurred_at: occurred_at,
             entity: nil
           }

    %EventReference{
      id: event_id,
      causation_id: event.causation_id,
      correlation_id: event.correlation_id
    }
  end

  defp assert_ansible_playbook_run_started_event!(
         %StoredEvent{id: event_id, occurred_at: occurred_at} = event,
         run,
         now,
         caused_by
       ) do
    assert_in_delta DateTime.diff(now, occurred_at, :second), 0, 1

    assert event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: event_id,
             stream: "servers:servers:#{run.server_id}",
             version: run.server.version,
             type: "archidep/servers/ansible-playbook-run-started",
             data: %{
               "id" => run.id,
               "playbook" => run.playbook,
               "playbook_path" => run.playbook_path,
               "playbook_digest" => Base.encode16(run.playbook_digest, case: :lower),
               "git_revision" => run.git_revision,
               "host" => run.host.address |> :inet.ntoa() |> to_string(),
               "port" => run.port,
               "user" => run.user,
               "vars" => run.vars,
               "vars_digest" => Base.encode16(run.vars_digest, case: :lower),
               "server" => %{
                 "id" => run.server_id,
                 "name" => run.server.name,
                 "username" => run.server.username
               },
               "group" => %{
                 "id" => run.server.group.id,
                 "name" => run.server.group.name
               },
               "owner" => %{
                 "id" => run.server.owner.id,
                 "username" => run.server.owner.username,
                 "name" =>
                   if run.server.owner.group_member do
                     run.server.owner.group_member.name
                   else
                     nil
                   end,
                 "root" => run.server.owner.root
               }
             },
             meta: %{},
             initiator: "servers:servers:#{run.server_id}",
             causation_id: caused_by.id,
             correlation_id: caused_by.correlation_id,
             occurred_at: occurred_at,
             entity: nil
           }

    %EventReference{
      id: event_id,
      causation_id: event.causation_id,
      correlation_id: event.correlation_id
    }
  end
end
