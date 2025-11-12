defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateHandleAccessCheckTaskResultTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Support.ServerManagerStateTestUtils
  import ExUnit.CaptureLog
  import Hammox
  alias ArchiDep.Servers.Ansible
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.ServerTracking.ServerManagerBehaviour
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.ServersFactory
  alias Phoenix.Token

  setup :verify_on_exit!

  setup_all do
    %{
      handle_task_result:
        protect({ServerManagerState, :handle_task_result, 3}, ServerManagerBehaviour)
    }
  end

  test "gather facts after sudo access has been confirmed with the application user", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: true, ssh_port: true)
    app_username = server.app_username

    fake_check_access_task_ref = make_ref()

    connected = ServersFactory.random_connected_state()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: connected,
        server: server,
        username: server.app_username,
        tasks: %{check_access: fake_check_access_task_ref}
      )

    result =
      handle_task_result.(
        initial_state,
        fake_check_access_task_ref,
        {:ok, Faker.Lorem.sentence(), Faker.Lorem.sentence(), 0}
      )

    assert_no_stored_events!()

    assert %{
             actions:
               [
                 {:demonitor, ^fake_check_access_task_ref},
                 {:gather_facts, ^app_username},
                 {:run_command, run_command_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{},
               ansible: :gathering_facts
           }

    fake_loadavg_task = Task.completed(:fake)

    loadavg_result =
      run_command_fn.(result, fn "cat /proc/loadavg", 10_000 ->
        fake_loadavg_task
      end)

    assert loadavg_result == %ServerManagerState{
             result
             | tasks: Map.put(result.tasks, :get_load_average, fake_loadavg_task.ref)
           }

    assert update_tracking_fn.(loadavg_result) ==
             {real_time_state(server,
                connection_state: connected,
                conn_params: conn_params(server, username: server.app_username),
                current_job: :gathering_facts,
                version: result.version + 1
              ), %ServerManagerState{loadavg_result | version: result.version + 1}}
  end

  test "run the setup playbook after sudo access has been confirmed with the normal user", %{
    handle_task_result: handle_task_result
  } do
    server = insert_active_server!(set_up_at: nil, ssh_port: true)

    fake_check_access_task_ref = make_ref()
    fake_connection_event = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()
    connected = ServersFactory.random_connected_state(connection_event: fake_connection_event)

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: connected,
        server: server,
        username: server.username,
        tasks: %{check_access: fake_check_access_task_ref}
      )

    expect(Ansible.Mock, :digest_ansible_variables, fn _vars ->
      Faker.random_bytes(10)
    end)

    now = DateTime.utc_now()

    result =
      handle_task_result.(
        initial_state,
        fake_check_access_task_ref,
        {:ok, Faker.Lorem.sentence(), Faker.Lorem.sentence(), 0}
      )

    assert %{
             actions:
               [
                 {:demonitor, ^fake_check_access_task_ref},
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

    [run_started_event] = fetch_new_stored_events([fake_connection_event])

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
             | actions: actions,
               ansible: {playbook_run, nil, fake_connection_event},
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
             user: server.username,
             vars: %{
               "api_base_url" => "http://localhost:42000/api",
               "app_user_name" => server.app_username,
               "app_user_authorized_key" => ssh_public_key(),
               "server_id" => server.id,
               "server_token" => server_token
             },
             vars_digest: vars_digest,
             server: server,
             server_id: server.id,
             state: :pending,
             started_at: nil,
             created_at: playbook_created_at,
             updated_at: playbook_created_at
           }

    server_id = server.id

    assert {:ok, ^server_id} =
             Token.verify(server.secret_key, "server auth", server_token, max_age: 5)

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: connected,
                current_job: {:running_playbook, playbook_run.playbook, playbook_run.id, nil},
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "install extra SSH public keys from the server group when running the setup playbook", %{
    handle_task_result: handle_task_result
  } do
    server =
      insert_active_server!(
        set_up_at: nil,
        ssh_port: true,
        class_teacher_ssh_public_keys: [
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC0V7EXAMPLEKEY key1",
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBEXAMPLEKEY key2"
        ]
      )

    fake_check_access_task_ref = make_ref()
    fake_connection_event = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()
    connected = ServersFactory.random_connected_state(connection_event: fake_connection_event)

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: connected,
        server: server,
        username: server.username,
        tasks: %{check_access: fake_check_access_task_ref}
      )

    expect(Ansible.Mock, :digest_ansible_variables, fn _vars ->
      Faker.random_bytes(10)
    end)

    now = DateTime.utc_now()

    result =
      handle_task_result.(
        initial_state,
        fake_check_access_task_ref,
        {:ok, Faker.Lorem.sentence(), Faker.Lorem.sentence(), 0}
      )

    assert %{
             actions:
               [
                 {:demonitor, ^fake_check_access_task_ref},
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

    [run_started_event] = fetch_new_stored_events([fake_connection_event])

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
             | actions: actions,
               ansible: {playbook_run, nil, fake_connection_event},
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
             user: server.username,
             vars: %{
               "api_base_url" => "http://localhost:42000/api",
               "app_user_name" => server.app_username,
               "app_user_authorized_key" =>
                 "#{ssh_public_key()}\nssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC0V7EXAMPLEKEY key1\nssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBEXAMPLEKEY key2",
               "server_id" => server.id,
               "server_token" => server_token
             },
             vars_digest: vars_digest,
             server: server,
             server_id: server.id,
             state: :pending,
             started_at: nil,
             created_at: playbook_created_at,
             updated_at: playbook_created_at
           }

    server_id = server.id

    assert {:ok, ^server_id} =
             Token.verify(server.secret_key, "server auth", server_token, max_age: 5)

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: connected,
                current_job: {:running_playbook, playbook_run.playbook, playbook_run.id, nil},
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "do not run the setup playbook after sudo access has been confirmed with the normal user if the three previous runs failed",
       %{
         handle_task_result: handle_task_result
       } do
    server = insert_active_server!(set_up_at: nil, ssh_port: true)

    failed_playbooks =
      1..3
      |> Enum.map(fn _n ->
        ServersFactory.insert(:ansible_playbook_run,
          playbook: "setup",
          server: server,
          state: ServersFactory.ansible_playbook_run_failed_state()
        )
      end)
      |> Enum.sort_by(& &1.created_at, {:desc, DateTime})

    fake_check_access_task_ref = make_ref()
    fake_connection_event = :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()
    connected = ServersFactory.random_connected_state(connection_event: fake_connection_event)

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: connected,
        server: server,
        username: server.username,
        tasks: %{check_access: fake_check_access_task_ref}
      )

    {result, msg} =
      with_log(fn ->
        handle_task_result.(
          initial_state,
          fake_check_access_task_ref,
          {:ok, Faker.Lorem.sentence(), Faker.Lorem.sentence(), 0}
        )
      end)

    assert msg =~
             "Not re-running Ansible setup playbook for server #{server.id} because it has failed 3 times"

    assert %{
             actions:
               [
                 {:demonitor, ^fake_check_access_task_ref},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert_no_stored_events!([fake_connection_event])

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               problems: [
                 {:server_ansible_playbook_repeatedly_failed,
                  Enum.map(failed_playbooks, &{"setup", &1.state, AnsiblePlaybookRun.stats(&1)})}
               ],
               tasks: %{}
           }

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: connected,
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "the setup process is stopped if the user does not have sudo access", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    fake_check_access_task_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username,
        tasks: %{check_access: fake_check_access_task_ref}
      )

    check_access_stderr = Faker.Lorem.sentence()

    result =
      handle_task_result.(
        initial_state,
        fake_check_access_task_ref,
        {:ok, Faker.Lorem.sentence(), check_access_stderr, Faker.random_between(1, 255)}
      )

    assert_no_stored_events!()

    assert %{
             actions:
               [
                 {:demonitor, ^fake_check_access_task_ref},
                 {:run_command, run_command_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{},
               problems: [{:server_missing_sudo_access, server.username, check_access_stderr}]
           }

    fake_loadavg_task = Task.completed(:fake)

    loadavg_result =
      run_command_fn.(result, fn "cat /proc/loadavg", 10_000 ->
        fake_loadavg_task
      end)

    assert loadavg_result == %ServerManagerState{
             result
             | tasks: %{get_load_average: fake_loadavg_task.ref}
           }

    assert update_tracking_fn.(loadavg_result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{loadavg_result | version: result.version + 1}}
  end

  test "fact gathering is not triggered if the application user does not have sudo access", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: true, ssh_port: true)

    fake_check_access_task_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        tasks: %{check_access: fake_check_access_task_ref}
      )

    check_access_stderr = Faker.Lorem.sentence()

    result =
      handle_task_result.(
        initial_state,
        fake_check_access_task_ref,
        {:ok, Faker.Lorem.sentence(), check_access_stderr, Faker.random_between(1, 255)}
      )

    assert_no_stored_events!()

    assert %{
             actions:
               [
                 {:demonitor, ^fake_check_access_task_ref},
                 {:run_command, run_command_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{},
               problems: [{:server_missing_sudo_access, server.app_username, check_access_stderr}]
           }

    fake_loadavg_task = Task.completed(:fake)

    loadavg_result =
      run_command_fn.(result, fn "cat /proc/loadavg", 10_000 ->
        fake_loadavg_task
      end)

    assert loadavg_result == %ServerManagerState{
             result
             | tasks: %{get_load_average: fake_loadavg_task.ref}
           }

    assert update_tracking_fn.(loadavg_result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{loadavg_result | version: result.version + 1}}
  end

  test "the setup process is stopped if sudo access cannot be checked", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    fake_check_access_task_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username,
        tasks: %{check_access: fake_check_access_task_ref}
      )

    check_access_error = Faker.Lorem.sentence()

    {result, log} =
      with_log(fn ->
        handle_task_result.(
          initial_state,
          fake_check_access_task_ref,
          {:error, check_access_error}
        )
      end)

    assert_no_stored_events!()

    assert log =~ "Server manager could not check sudo access to server #{server.id}"

    assert %{
             actions:
               [
                 {:demonitor, ^fake_check_access_task_ref},
                 {:run_command, run_command_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{},
               problems: [{:server_sudo_access_check_failed, server.username, check_access_error}]
           }

    fake_loadavg_task = Task.completed(:fake)

    loadavg_result =
      run_command_fn.(result, fn "cat /proc/loadavg", 10_000 ->
        fake_loadavg_task
      end)

    assert loadavg_result == %ServerManagerState{
             result
             | tasks: %{get_load_average: fake_loadavg_task.ref}
           }

    assert update_tracking_fn.(loadavg_result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{loadavg_result | version: result.version + 1}}
  end

  test "fact gathering is not triggered if sudo access cannot be checked", %{
    handle_task_result: handle_task_result
  } do
    server = build_active_server(set_up_at: true, ssh_port: true)

    fake_check_access_task_ref = make_ref()

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        tasks: %{check_access: fake_check_access_task_ref}
      )

    check_access_error = Faker.Lorem.sentence()

    {result, log} =
      with_log(fn ->
        handle_task_result.(
          initial_state,
          fake_check_access_task_ref,
          {:error, check_access_error}
        )
      end)

    assert log =~ "Server manager could not check sudo access to server #{server.id}"
    assert_no_stored_events!()

    assert %{
             actions:
               [
                 {:demonitor, ^fake_check_access_task_ref},
                 {:run_command, run_command_fn},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               tasks: %{},
               problems: [
                 {:server_sudo_access_check_failed, server.app_username, check_access_error}
               ]
           }

    fake_loadavg_task = Task.completed(:fake)

    loadavg_result =
      run_command_fn.(result, fn "cat /proc/loadavg", 10_000 ->
        fake_loadavg_task
      end)

    assert loadavg_result == %ServerManagerState{
             result
             | tasks: %{get_load_average: fake_loadavg_task.ref}
           }

    assert update_tracking_fn.(loadavg_result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                conn_params: conn_params(server, username: server.app_username),
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{loadavg_result | version: result.version + 1}}
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
