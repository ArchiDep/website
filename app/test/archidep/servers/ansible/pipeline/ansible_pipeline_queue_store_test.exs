defmodule ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueueStoreTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueueStore
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookEvent
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Support.ServersFactory
  alias ArchiDep.Support.ServersTestHelpers

  # The store stamps the timeout from `Clock.now/0`, so a fixed instant makes
  # the timed-out runs and their events deterministic.
  @now ~U[2024-03-15 10:30:00.000000Z]
  @past ~U[2024-01-01 00:00:00.000000Z]

  @affected_tables [AnsiblePlaybookRun, AnsiblePlaybookEvent, StoredEvent]

  setup do
    stub(ArchiDep.Clock.Mock, :now, fn -> @now end)
    %{server: server_fixture()}
  end

  defp server_fixture do
    %{owner: owner, class: class} = ServersTestHelpers.register_group_member(@past)
    ServersTestHelpers.insert_server(owner.id, class.id, active: true, ssh_port: 2222)
  end

  describe "mark_incomplete_runs_as_timed_out/0" do
    test "times out every pending and running run and leaves terminal runs alone", %{
      server: server
    } do
      pending = insert_run(server, :pending)
      # `started_at` must precede the timeout instant `@now`, or `time_out`'s
      # start/finish ordering validation would reject the change.
      running = insert_run(server, :running, started_at: @past)
      done = insert_run(server, :succeeded)

      existing = fetch_new_stored_events()
      previous_counts = count_rows(@affected_tables)

      assert AnsiblePipelineQueueStore.mark_incomplete_runs_as_timed_out() == :ok

      assert Repo.get!(AnsiblePlaybookRun, pending.id) == timed_out(pending)
      assert Repo.get!(AnsiblePlaybookRun, running.id) == timed_out(running)
      assert Repo.get!(AnsiblePlaybookRun, done.id) == done

      events = fetch_new_stored_events(existing)
      assert_run_finished_event!(pending, server, events)
      assert_run_finished_event!(running, server, events)

      assert_row_count_diff(previous_counts, %{StoredEvent => 2})
    end

    test "does nothing when there are no incomplete runs", %{server: server} do
      ServersFactory.insert(:ansible_playbook_run, server: server, state: :failed)
      previous_counts = count_rows(@affected_tables)

      assert AnsiblePipelineQueueStore.mark_incomplete_runs_as_timed_out() == :ok

      assert_no_row_count_diff(previous_counts)
    end
  end

  # Reload as the baseline so the `Postgrex.INET` `/32` round-trip (`netmask:
  # nil` built vs `32` reloaded) and the unloaded server association do not
  # spuriously differ from the row the store updates.
  defp insert_run(server, state, attrs \\ []),
    do:
      :ansible_playbook_run
      |> ServersFactory.insert([server: server, state: state] ++ attrs)
      |> Map.fetch!(:id)
      |> then(&Repo.get!(AnsiblePlaybookRun, &1))

  defp timed_out(run),
    do: %{run | state: :timeout, finished_at: @now, updated_at: @now}

  # The store creates a root run-finished event (no cause), so its causation and
  # correlation ids are its own. The runs are timed out in parallel, so events
  # are matched to their run by id rather than by position.
  defp assert_run_finished_event!(run, server, events) do
    assert %StoredEvent{id: event_id} = event = Enum.find(events, &(&1.data["id"] == run.id))

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
                 "playbook" => run.playbook,
                 "host" => host_string(run),
                 "port" => run.port,
                 "user" => run.user,
                 "state" => "timeout",
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
               causation_id: event_id,
               correlation_id: event_id,
               occurred_at: @now,
               entity: nil
             }
  end

  defp host_string(run), do: run.host.address |> :inet.ntoa() |> to_string()

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
