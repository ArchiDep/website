defmodule ArchiDep.Servers.Ansible.TrackerTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox
  alias ArchiDep.Clock
  alias ArchiDep.Servers.Ansible.Tracker
  alias ArchiDep.Servers.Schemas.AnsiblePlaybook
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookEvent
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.ServersTestHelpers

  # The tracker stamps every timestamp from `Clock.now/0`, so a fixed instant
  # makes the persisted runs, events and stored events deterministic.
  @now ~U[2024-03-15 10:30:00.000000Z]
  # A safely-past instant for the persisted owner/group/server graph.
  @past ~U[2024-01-01 00:00:00.000000Z]

  @user "deploy"
  @vars %{"ansible_connection" => "ssh", "ansible_user" => "deploy"}
  @vars_digest "vars-digest"

  # Everything the tracker can write to, watched by every row-count diff.
  @affected_tables [AnsiblePlaybookRun, AnsiblePlaybookEvent, StoredEvent]

  setup do
    stub(Clock.Mock, :now, fn -> @now end)
    %{server: server_fixture()}
  end

  describe "track_playbook!/6" do
    test "inserts a pending run and stores a run-started event", %{server: server} do
      cause = event_reference()
      existing = fetch_new_stored_events()
      previous_counts = count_rows(@affected_tables)

      {run, ref} = Tracker.track_playbook!(playbook(), server, @user, @vars, @vars_digest, cause)

      event =
        run
        |> assert_pending_run(server)
        |> assert_run_started_event(server, cause, existing)

      assert ref == StoredEvent.to_reference(event)

      assert Repo.get!(AnsiblePlaybookRun, run.id) ==
               %{run | server: not_loaded(:server, AnsiblePlaybookRun)}

      assert_row_count_diff(previous_counts, %{AnsiblePlaybookRun => 1, StoredEvent => 1})
    end
  end

  describe "track_playbook_event/4 with an event" do
    test "persists the event, touches the run and stores an event-occurred event", %{
      server: server
    } do
      {run, started_cause} = pending_run(server)
      running_cause = event_reference()
      existing = fetch_new_stored_events()

      data = %{
        "_event" => "v2_runner_on_ok",
        "hosts" => %{"archidep" => %{"action" => "command", "changed" => true}}
      }

      previous_counts = count_rows(@affected_tables)

      assert {:event, event} =
               Tracker.track_playbook_event({:event, data}, run, started_cause, running_cause)

      assert event ==
               %AnsiblePlaybookEvent{
                 __meta__: loaded(AnsiblePlaybookEvent, "ansible_playbook_events"),
                 id: event.id,
                 run: run,
                 run_id: run.id,
                 name: "v2_runner_on_ok",
                 action: "command",
                 changed: true,
                 data: data,
                 task_name: nil,
                 task_id: nil,
                 task_started_at: nil,
                 task_ended_at: nil,
                 occurred_at: @now,
                 created_at: @now
               }

      assert Repo.get!(AnsiblePlaybookEvent, event.id) ==
               %{event | run: not_loaded(:run, AnsiblePlaybookEvent)}

      assert Repo.get!(AnsiblePlaybookRun, run.id) ==
               %{
                 run
                 | server: not_loaded(:server, AnsiblePlaybookRun),
                   number_of_events: 1,
                   last_event_at: @now,
                   updated_at: @now
               }

      assert_event_occurred_event(event, run, server, existing, running_cause, data)

      assert_row_count_diff(previous_counts, %{AnsiblePlaybookEvent => 1, StoredEvent => 1})
    end

    test "copies the run statistics from a stats event", %{server: server} do
      {run, started_cause} = pending_run(server)
      running_cause = event_reference()
      existing = fetch_new_stored_events()

      data = %{
        "_event" => "v2_playbook_on_stats",
        "stats" => %{
          "archidep" => %{
            "changed" => 1,
            "failures" => 2,
            "ignored" => 3,
            "ok" => 4,
            "rescued" => 5,
            "skipped" => 6,
            "unreachable" => 7
          }
        }
      }

      previous_counts = count_rows(@affected_tables)

      assert {:event, event} =
               Tracker.track_playbook_event({:event, data}, run, started_cause, running_cause)

      assert event ==
               %AnsiblePlaybookEvent{
                 __meta__: loaded(AnsiblePlaybookEvent, "ansible_playbook_events"),
                 id: event.id,
                 run: run,
                 run_id: run.id,
                 name: "v2_playbook_on_stats",
                 action: nil,
                 changed: false,
                 data: data,
                 task_name: nil,
                 task_id: nil,
                 task_started_at: nil,
                 task_ended_at: nil,
                 occurred_at: @now,
                 created_at: @now
               }

      assert Repo.get!(AnsiblePlaybookRun, run.id) ==
               %{
                 run
                 | server: not_loaded(:server, AnsiblePlaybookRun),
                   number_of_events: 1,
                   last_event_at: @now,
                   updated_at: @now,
                   stats_changed: 1,
                   stats_failures: 2,
                   stats_ignored: 3,
                   stats_ok: 4,
                   stats_rescued: 5,
                   stats_skipped: 6,
                   stats_unreachable: 7
               }

      assert_event_occurred_event(event, run, server, existing, running_cause, data)

      assert_row_count_diff(previous_counts, %{AnsiblePlaybookEvent => 1, StoredEvent => 1})
    end
  end

  describe "track_playbook_event/4 with an exit" do
    test "succeeds the run and stores a run-finished event on a zero status", %{server: server} do
      {run, started_cause} = running_run(server)
      existing = fetch_new_stored_events()
      previous_counts = count_rows(@affected_tables)

      assert {:succeeded, finished} =
               Tracker.track_playbook_event(
                 {:exit, {:status, 0}},
                 run,
                 started_cause,
                 started_cause
               )

      assert finished ==
               %{run | state: :succeeded, exit_code: 0, finished_at: @now, updated_at: @now}

      assert Repo.get!(AnsiblePlaybookRun, run.id) ==
               %{
                 run
                 | server: not_loaded(:server, AnsiblePlaybookRun),
                   state: :succeeded,
                   exit_code: 0,
                   finished_at: @now,
                   updated_at: @now
               }

      assert_run_finished_event(finished, server, started_cause, existing)

      assert_row_count_diff(previous_counts, %{StoredEvent => 1})
    end

    test "fails the run with the exit code on a non-zero status", %{server: server} do
      {run, started_cause} = running_run(server)
      existing = fetch_new_stored_events()
      previous_counts = count_rows(@affected_tables)

      assert {:failed, finished} =
               Tracker.track_playbook_event(
                 {:exit, {:status, 42}},
                 run,
                 started_cause,
                 started_cause
               )

      assert finished ==
               %{run | state: :failed, exit_code: 42, finished_at: @now, updated_at: @now}

      assert Repo.get!(AnsiblePlaybookRun, run.id) ==
               %{
                 run
                 | server: not_loaded(:server, AnsiblePlaybookRun),
                   state: :failed,
                   exit_code: 42,
                   finished_at: @now,
                   updated_at: @now
               }

      assert_run_finished_event(finished, server, started_cause, existing)

      assert_row_count_diff(previous_counts, %{StoredEvent => 1})
    end

    test "fails the run with no exit code on an epipe", %{server: server} do
      {run, started_cause} = running_run(server)
      existing = fetch_new_stored_events()
      previous_counts = count_rows(@affected_tables)

      assert {:failed, finished} =
               Tracker.track_playbook_event({:exit, :epipe}, run, started_cause, started_cause)

      assert finished ==
               %{run | state: :failed, exit_code: nil, finished_at: @now, updated_at: @now}

      assert Repo.get!(AnsiblePlaybookRun, run.id) ==
               %{
                 run
                 | server: not_loaded(:server, AnsiblePlaybookRun),
                   state: :failed,
                   exit_code: nil,
                   finished_at: @now,
                   updated_at: @now
               }

      assert_run_finished_event(finished, server, started_cause, existing)

      assert_row_count_diff(previous_counts, %{StoredEvent => 1})
    end
  end

  defp server_fixture do
    %{owner: owner, class: class} = ServersTestHelpers.register_group_member(@past)
    ServersTestHelpers.insert_server(owner.id, class.id, active: true, ssh_port: 2222)
  end

  defp pending_run(server),
    do: Tracker.track_playbook!(playbook(), server, @user, @vars, @vars_digest, event_reference())

  defp running_run(server) do
    {run, started_cause} = pending_run(server)
    {:ok, running} = run |> AnsiblePlaybookRun.start_running(@now) |> Repo.update()
    {running, started_cause}
  end

  defp playbook, do: AnsiblePlaybook.new("playbooks/setup.yml", "playbook-digest")

  # The events table has foreign keys on `causation_id`/`correlation_id`, so a
  # cause must be a real stored event. A factory `stored_event` is a root event
  # (its causation and correlation IDs are its own), which both keys can target.
  defp event_reference, do: :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()

  defp assert_pending_run(run, server) do
    assert run ==
             %AnsiblePlaybookRun{
               __meta__: loaded(AnsiblePlaybookRun, "ansible_playbook_runs"),
               id: run.id,
               playbook: "setup",
               playbook_path: "playbooks/setup.yml",
               playbook_digest: "playbook-digest",
               git_revision: run.git_revision,
               host: server.ip_address,
               port: 2222,
               user: @user,
               vars: @vars,
               vars_digest: @vars_digest,
               server: server,
               server_id: server.id,
               state: :pending,
               started_at: nil,
               finished_at: nil,
               number_of_events: 0,
               last_event_at: nil,
               exit_code: nil,
               stats_changed: 0,
               stats_failures: 0,
               stats_ignored: 0,
               stats_ok: 0,
               stats_rescued: 0,
               stats_skipped: 0,
               stats_unreachable: 0,
               created_at: @now,
               updated_at: @now
             }

    run
  end

  defp assert_run_started_event(run, server, cause, existing) do
    assert [%StoredEvent{id: event_id} = event] = fetch_new_stored_events(existing)

    assert event ==
             %StoredEvent{
               __meta__: loaded(StoredEvent, "events"),
               id: event_id,
               stream: "servers:servers:#{server.id}",
               version: server.version,
               schema_version: 1,
               type: "archidep/servers/ansible-playbook-run-started",
               data: %{
                 "id" => run.id,
                 "playbook" => "setup",
                 "playbook_path" => "playbooks/setup.yml",
                 "playbook_digest" => Base.encode16("playbook-digest", case: :lower),
                 "git_revision" => run.git_revision,
                 "host" => host_string(server),
                 "port" => 2222,
                 "user" => @user,
                 "vars" => @vars,
                 "vars_digest" => Base.encode16(@vars_digest, case: :lower),
                 "server" => server_data(server),
                 "group" => group_data(server),
                 "owner" => owner_data(server.owner)
               },
               meta: %{},
               initiator: "servers:servers:#{server.id}",
               causation_id: cause.id,
               correlation_id: cause.correlation_id,
               occurred_at: @now,
               entity: nil
             }

    event
  end

  defp assert_event_occurred_event(event, run, server, existing, cause, data) do
    assert [%StoredEvent{id: event_id} = stored] = fetch_new_stored_events(existing)

    assert stored ==
             %StoredEvent{
               __meta__: loaded(StoredEvent, "events"),
               id: event_id,
               stream: "servers:servers:#{server.id}",
               version: server.version,
               schema_version: 1,
               type: "archidep/servers/ansible-playbook-event-occurred",
               data: %{
                 "id" => event.id,
                 "properties" => data,
                 "playbook_run" => %{
                   "id" => run.id,
                   "playbook" => "setup",
                   "host" => host_string(server),
                   "port" => 2222,
                   "user" => @user
                 },
                 "server" => server_data(server),
                 "group" => group_data(server),
                 "owner" => owner_data(server.owner)
               },
               meta: %{},
               initiator: "servers:servers:#{server.id}",
               causation_id: cause.id,
               correlation_id: cause.correlation_id,
               occurred_at: @now,
               entity: nil
             }

    stored
  end

  defp assert_run_finished_event(run, server, cause, existing) do
    assert [%StoredEvent{id: event_id} = event] = fetch_new_stored_events(existing)

    assert event ==
             %StoredEvent{
               __meta__: loaded(StoredEvent, "events"),
               id: event_id,
               stream: "servers:servers:#{server.id}",
               version: server.version,
               schema_version: 1,
               type: "archidep/servers/ansible-playbook-run-finished",
               data: %{
                 "id" => run.id,
                 "playbook" => "setup",
                 "host" => host_string(server),
                 "port" => 2222,
                 "user" => @user,
                 "state" => Atom.to_string(run.state),
                 "number_of_events" => run.number_of_events,
                 "exit_code" => run.exit_code,
                 "stats" => %{
                   "changed" => run.stats_changed,
                   "failures" => run.stats_failures,
                   "ignored" => run.stats_ignored,
                   "ok" => run.stats_ok,
                   "rescued" => run.stats_rescued,
                   "skipped" => run.stats_skipped,
                   "unreachable" => run.stats_unreachable
                 },
                 "server" => server_data(server),
                 "group" => group_data(server),
                 "owner" => owner_data(server.owner)
               },
               meta: %{},
               initiator: "servers:servers:#{server.id}",
               causation_id: cause.id,
               correlation_id: cause.correlation_id,
               occurred_at: @now,
               entity: nil
             }

    event
  end

  defp host_string(server), do: server.ip_address.address |> :inet.ntoa() |> to_string()

  defp server_data(server),
    do: %{"id" => server.id, "name" => server.name, "username" => server.username}

  defp group_data(server), do: %{"id" => server.group.id, "name" => server.group.name}

  defp owner_data(%ServerOwner{} = owner),
    do: %{
      "id" => owner.id,
      "username" => owner.username,
      "name" => owner.group_member.name,
      "root" => owner.root
    }
end
