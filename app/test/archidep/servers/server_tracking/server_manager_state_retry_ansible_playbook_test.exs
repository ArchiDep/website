defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateRetryAnsiblePlaybookTest do
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Support.ServerManagerStateTestUtils
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
      retry_ansible_playbook:
        protect({ServerManagerState, :retry_ansible_playbook, 2}, ServerManagerBehaviour)
    }
  end

  test "retry running the ansible setup playbook", %{
    retry_ansible_playbook: retry_ansible_playbook
  } do
    server = insert_active_server!(set_up_at: nil, ssh_port: true)

    ServersFactory.insert(:ansible_playbook_run,
      server: server,
      state: ServersFactory.ansible_playbook_run_failed_state()
    )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username,
        problems: [
          ServersFactory.server_ansible_playbook_failed_problem(playbook: "setup")
        ]
      )

    now = DateTime.utc_now()

    assert {result, :ok} =
             retry_ansible_playbook.(
               initial_state,
               "setup"
             )

    assert %{
             actions:
               [
                 {:run_playbook,
                  %{
                    git_revision: git_revision,
                    vars: %{"server_token" => server_token},
                    created_at: playbook_created_at
                  } =
                    playbook_run, playbook_run_cause},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    {retried_event, started_event} = assert_retried_ansible_playbook_events!(playbook_run, now)
    assert playbook_run_cause == started_event

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               ansible_playbook: {playbook_run, nil, retried_event}
           }

    assert_in_delta DateTime.diff(now, playbook_created_at, :second), 0, 1

    assert playbook_run == %AnsiblePlaybookRun{
             __meta__: loaded(AnsiblePlaybookRun, "ansible_playbook_runs"),
             id: playbook_run.id,
             playbook: "setup",
             playbook_path: "priv/ansible/playbooks/setup.yml",
             digest: Ansible.setup_playbook().digest,
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
             server: server,
             server_id: server.id,
             state: :pending,
             started_at: playbook_created_at,
             created_at: playbook_created_at,
             updated_at: playbook_created_at
           }

    server_id = server.id

    assert {:ok, ^server_id} =
             Token.verify(server.secret_key, "server auth", server_token, max_age: 5)

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                current_job: {:running_playbook, playbook_run.playbook, playbook_run.id, nil},
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "retry running the ansible setup playbook with other problems", %{
    retry_ansible_playbook: retry_ansible_playbook
  } do
    server = insert_active_server!(set_up_at: nil, ssh_port: true)

    ServersFactory.insert(:ansible_playbook_run,
      server: server,
      state: ServersFactory.ansible_playbook_run_failed_state()
    )

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username,
        problems: [
          ServersFactory.server_expected_property_mismatch_problem(),
          ServersFactory.server_ansible_playbook_failed_problem(playbook: "setup")
        ]
      )

    now = DateTime.utc_now()

    assert {result, :ok} =
             retry_ansible_playbook.(
               initial_state,
               "setup"
             )

    assert %{
             actions:
               [
                 {:run_playbook,
                  %{
                    git_revision: git_revision,
                    vars: %{"server_token" => server_token},
                    created_at: playbook_created_at
                  } =
                    playbook_run, playbook_run_cause},
                 {:update_tracking, "servers", update_tracking_fn}
               ] = actions
           } = result

    {retried_event, started_event} = assert_retried_ansible_playbook_events!(playbook_run, now)
    assert playbook_run_cause == started_event

    assert result == %ServerManagerState{
             initial_state
             | actions: actions,
               ansible_playbook: {playbook_run, nil, retried_event}
           }

    assert_in_delta DateTime.diff(now, playbook_created_at, :second), 0, 1

    assert playbook_run == %AnsiblePlaybookRun{
             __meta__: loaded(AnsiblePlaybookRun, "ansible_playbook_runs"),
             id: playbook_run.id,
             playbook: "setup",
             playbook_path: "priv/ansible/playbooks/setup.yml",
             digest: Ansible.setup_playbook().digest,
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
             server: server,
             server_id: server.id,
             state: :pending,
             started_at: playbook_created_at,
             created_at: playbook_created_at,
             updated_at: playbook_created_at
           }

    server_id = server.id

    assert {:ok, ^server_id} =
             Token.verify(server.secret_key, "server auth", server_token, max_age: 5)

    assert update_tracking_fn.(result) ==
             {real_time_state(server,
                connection_state: initial_state.connection_state,
                current_job: {:running_playbook, playbook_run.playbook, playbook_run.id, nil},
                problems: result.problems,
                version: result.version + 1
              ), %ServerManagerState{result | version: result.version + 1}}
  end

  test "cannot retry running the ansible setup playbook if the problem is not present", %{
    retry_ansible_playbook: retry_ansible_playbook
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username,
        problems: []
      )

    assert retry_ansible_playbook.(initial_state, "setup") == {initial_state, :ok}

    assert_no_stored_events!()
  end

  test "cannot retry running the ansible setup playbook as the application user if the problem is not present",
       %{
         retry_ansible_playbook: retry_ansible_playbook
       } do
    server = build_active_server(set_up_at: true, ssh_port: true)

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.app_username,
        problems: []
      )

    assert retry_ansible_playbook.(initial_state, "setup") == {initial_state, :ok}

    assert_no_stored_events!()
  end

  test "cannot retry running the ansible setup playbook if the server is busy running a task", %{
    retry_ansible_playbook: retry_ansible_playbook
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username,
        problems: [
          ServersFactory.server_ansible_playbook_failed_problem(playbook: "setup")
        ],
        tasks: %{get_load_average: make_ref()}
      )

    assert retry_ansible_playbook.(initial_state, "setup") ==
             {initial_state, {:error, :server_busy}}

    assert_no_stored_events!()
  end

  test "cannot retry running the ansible setup playbook if the server is busy running an ansible playbook",
       %{
         retry_ansible_playbook: retry_ansible_playbook
       } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    running_playbook =
      ServersFactory.build(:ansible_playbook_run, server: server, state: :pending)

    fake_cause = EventsFactory.build(:event_reference)

    initial_state =
      ServersFactory.build(:server_manager_state,
        connection_state: ServersFactory.random_connected_state(),
        server: server,
        username: server.username,
        problems: [
          ServersFactory.server_ansible_playbook_failed_problem(playbook: "setup")
        ],
        ansible_playbook: {running_playbook, nil, fake_cause}
      )

    assert retry_ansible_playbook.(initial_state, "setup") ==
             {initial_state, {:error, :server_busy}}

    assert_no_stored_events!()
  end

  test "cannot retry running the ansible setup playbook if the server is not connected", %{
    retry_ansible_playbook: retry_ansible_playbook
  } do
    server = build_active_server(set_up_at: nil, ssh_port: true)

    for connection_state <-
          [
            ServersFactory.random_not_connected_state(),
            ServersFactory.random_connecting_state(),
            ServersFactory.random_retry_connecting_state(),
            ServersFactory.random_reconnecting_state(),
            ServersFactory.random_connection_failed_state(),
            ServersFactory.random_disconnected_state()
          ] do
      initial_state =
        ServersFactory.build(:server_manager_state,
          connection_state: connection_state,
          server: server,
          username: server.username,
          problems: [
            ServersFactory.server_ansible_playbook_failed_problem(playbook: "setup")
          ]
        )

      assert retry_ansible_playbook.(initial_state, "setup") ==
               {initial_state, {:error, :server_not_connected}}
    end

    assert_no_stored_events!()
  end

  defp assert_retried_ansible_playbook_events!(run, now) do
    assert [
             %StoredEvent{
               id: retried_event_id,
               occurred_at: retried_occurred_at
             } = retried_event,
             %StoredEvent{
               id: run_started_event_id,
               occurred_at: run_started_occurred_at
             } = run_started_event
           ] =
             Repo.all(
               from e in StoredEvent,
                 order_by: [asc: e.occurred_at]
             )

    assert_in_delta DateTime.diff(now, retried_occurred_at, :second), 0, 1
    assert_in_delta DateTime.diff(now, run_started_occurred_at, :second), 0, 1

    server = run.server

    assert retried_event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: retried_event_id,
             stream: "servers:servers:#{server.id}",
             version: server.version,
             type: "archidep/servers/server-retried-ansible-playbook",
             data: %{
               "id" => server.id,
               "name" => server.name,
               "ip_address" => server.ip_address.address |> :inet.ntoa() |> to_string(),
               "username" => server.username,
               "ssh_username" =>
                 if(server.set_up_at, do: server.app_username, else: server.username),
               "ssh_port" => server.ssh_port,
               "playbook" => run.playbook,
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
             causation_id: retried_event_id,
             correlation_id: retried_event_id,
             occurred_at: retried_occurred_at,
             entity: nil
           }

    assert run_started_event == %StoredEvent{
             __meta__: loaded(StoredEvent, "events"),
             id: run_started_event_id,
             stream: "servers:servers:#{run.server_id}",
             version: run.server.version,
             type: "archidep/servers/ansible-playbook-run-started",
             data: %{
               "id" => run.id,
               "playbook" => run.playbook,
               "playbook_path" => run.playbook_path,
               "digest" => Base.encode16(run.digest, case: :lower),
               "git_revision" => run.git_revision,
               "host" => run.host.address |> :inet.ntoa() |> to_string(),
               "port" => run.port,
               "user" => run.user,
               "vars" => run.vars,
               "server" => %{
                 "id" => run.server_id,
                 "name" => server.name,
                 "username" => server.username
               },
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
             initiator: "servers:servers:#{run.server_id}",
             causation_id: retried_event.id,
             correlation_id: retried_event.correlation_id,
             occurred_at: run_started_occurred_at,
             entity: nil
           }

    {
      %EventReference{
        id: retried_event_id,
        causation_id: retried_event.causation_id,
        correlation_id: retried_event.correlation_id
      },
      %EventReference{
        id: run_started_event_id,
        causation_id: run_started_event.causation_id,
        correlation_id: run_started_event.correlation_id
      }
    }
  end
end
