defmodule ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineRunnerTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox
  import ArchiDep.Support.TelemetryTestHelpers
  alias ArchiDep.Events.Store.StoredEvent
  alias ArchiDep.Servers.Ansible
  alias ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineRunner
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookEvent
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Servers.ServerTracking.ServerManagerClientMock
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.ServersFactory
  alias ArchiDep.Support.ServersTestHelpers
  alias Ecto.UUID

  # `AnsiblePipelineRunner` is a `Task` wrapping `process_event/1`; the Task is
  # trivial wiring, so we exercise the logic by calling `process_event/1`
  # directly in the test process. That keeps the owner-scoped mocks
  # (`Ansible.Mock`, `ServerManagerClientMock`) and the SQL sandbox owned by the
  # test, so no `allow`/`set_mox_global` is needed.
  #
  # The Ansible boundary is mocked, so the playbook event/finish persistence
  # done by `Ansible.Tracker` inside the real stream does not run here (it is
  # covered by `tracker_test.exs`); these tests assert only what the runner
  # itself writes — the `start_running`/`interrupt` transition and its stored
  # event.

  @now ~U[2024-03-15 10:30:00.000000Z]
  @past ~U[2024-01-01 00:00:00.000000Z]

  @affected_tables [AnsiblePlaybookRun, AnsiblePlaybookEvent, StoredEvent]

  @gather_facts_event [:archidep, :servers, :ansible, :gather_facts]
  @playbook_run_event [:archidep, :servers, :ansible, :playbook_run]
  @playbook_run_interrupted_event [:archidep, :servers, :ansible, :playbook_run, :interrupted]

  setup :verify_on_exit!

  setup context do
    stub(ArchiDep.Clock.Mock, :now, fn -> @now end)
    attach_telemetry_handler!(context, @gather_facts_event ++ [:stop])
    attach_telemetry_handler!(context, @playbook_run_event ++ [:stop])
    attach_telemetry_handler!(context, @playbook_run_interrupted_event)
    %{server: server_fixture()}
  end

  defp server_fixture do
    %{owner: owner, class: class} = ServersTestHelpers.register_group_member(@past)
    ServersTestHelpers.insert_server(owner.id, class.id, active: true, ssh_port: 2222)
  end

  # The events table has foreign keys on `causation_id`/`correlation_id`, so a
  # cause must be a real stored event (its own root).
  defp cause, do: :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()

  defp pending_run(server),
    do:
      :ansible_playbook_run
      |> ServersFactory.insert(server: server, state: :pending)
      |> Map.fetch!(:id)
      |> AnsiblePlaybookRun.get_pending_run()

  describe "process_event/1 gathering facts" do
    test "gathers facts and reports them when the server is online", %{server: server} do
      facts = %{"ansible_distribution" => "Ubuntu"}
      previous_counts = count_rows(@affected_tables)

      expect(ServerManagerClientMock, :online?, fn ^server -> true end)
      expect(Ansible.Mock, :gather_facts, fn ^server, "deploy" -> {:ok, facts} end)

      expect(ServerManagerClientMock, :ansible_facts_gathered, fn ^server, {:ok, ^facts} ->
        :ok
      end)

      assert AnsiblePipelineRunner.process_event({:gather_facts, server.id, "deploy"}) == :ok

      assert_no_row_count_diff(previous_counts)
      assert_no_stored_events!()
      assert_span_stop!(@gather_facts_event, %{server_id: server.id})
    end

    test "reports the error when fact gathering fails", %{server: server} do
      previous_counts = count_rows(@affected_tables)

      expect(ServerManagerClientMock, :online?, fn ^server -> true end)
      expect(Ansible.Mock, :gather_facts, fn ^server, "deploy" -> {:error, :unreachable} end)

      expect(ServerManagerClientMock, :ansible_facts_gathered, fn ^server,
                                                                  {:error, :unreachable} ->
        :ok
      end)

      assert AnsiblePipelineRunner.process_event({:gather_facts, server.id, "deploy"}) == :ok

      assert_no_row_count_diff(previous_counts)
      assert_no_stored_events!()
      assert_span_stop!(@gather_facts_event, %{server_id: server.id})
    end

    test "does nothing when the server is offline", %{server: server} do
      previous_counts = count_rows(@affected_tables)

      expect(ServerManagerClientMock, :online?, fn ^server -> false end)

      assert AnsiblePipelineRunner.process_event({:gather_facts, server.id, "deploy"}) == :ok

      assert_no_row_count_diff(previous_counts)
      assert_no_stored_events!()
      refute_received {:telemetry_event, _event, _data}
    end
  end

  describe "process_event/1 running a playbook" do
    test "does nothing when the run is not pending", %{server: server} do
      run = ServersFactory.insert(:ansible_playbook_run, server: server, state: :succeeded)
      cause = cause()
      previous_counts = count_rows(@affected_tables)

      assert AnsiblePipelineRunner.process_event({:run_playbook, run.id, cause}) == :ok

      # The all-zero diff (snapshotted after the cause event) proves the no-op
      # wrote nothing; an absolute `assert_no_stored_events!/0` would trip on
      # the cause event that the foreign keys require.
      assert_no_row_count_diff(previous_counts)
      refute_received {:telemetry_event, _event, _data}
    end

    test "starts the run and streams its events when the server is online", %{server: server} do
      pending = pending_run(server)
      expected_server = pending.server
      cause = cause()
      running = start_running(pending)

      # The runner only reads `task_name`, but the `ServerManagerClient`
      # contract checks the whole event, so the `run` association is left
      # unloaded (valid per its type) rather than carrying a half-loaded
      # association.
      event =
        ServersFactory.build(:ansible_playbook_event,
          run: not_loaded(:run, AnsiblePlaybookEvent),
          run_id: UUID.generate()
        )

      succeeded = %{
        running
        | state: :succeeded,
          exit_code: 0,
          finished_at: @now,
          updated_at: @now
      }

      existing = fetch_new_stored_events()
      previous_counts = count_rows(@affected_tables)

      expect(ServerManagerClientMock, :online?, fn ^expected_server -> true end)

      expect(Ansible.Mock, :run_playbook, fn ^running, ^cause, _ref ->
        [{:event, event}, {:succeeded, succeeded}]
      end)

      expect(ServerManagerClientMock, :ansible_playbook_event, fn ^running, ^event -> :ok end)
      expect(ServerManagerClientMock, :ansible_playbook_completed, fn ^succeeded -> :ok end)

      assert AnsiblePipelineRunner.process_event({:run_playbook, pending.id, cause}) == :ok

      assert Repo.get!(AnsiblePlaybookRun, pending.id) ==
               %{running | server: not_loaded(:server, AnsiblePlaybookRun)}

      assert_run_running_event(running, server, cause, existing)
      assert_row_count_diff(previous_counts, %{StoredEvent => 1})

      assert_span_stop!(@playbook_run_event, %{
        state: :succeeded,
        server_id: server.id,
        playbook: pending.playbook
      })
    end

    test "completes a failed run when the playbook fails", %{server: server} do
      pending = pending_run(server)
      expected_server = pending.server
      cause = cause()
      running = start_running(pending)
      failed = %{running | state: :failed, exit_code: 2, finished_at: @now, updated_at: @now}

      existing = fetch_new_stored_events()
      previous_counts = count_rows(@affected_tables)

      expect(ServerManagerClientMock, :online?, fn ^expected_server -> true end)
      expect(Ansible.Mock, :run_playbook, fn ^running, ^cause, _ref -> [{:failed, failed}] end)
      expect(ServerManagerClientMock, :ansible_playbook_completed, fn ^failed -> :ok end)

      assert AnsiblePipelineRunner.process_event({:run_playbook, pending.id, cause}) == :ok

      assert Repo.get!(AnsiblePlaybookRun, pending.id) ==
               %{running | server: not_loaded(:server, AnsiblePlaybookRun)}

      assert_run_running_event(running, server, cause, existing)
      assert_row_count_diff(previous_counts, %{StoredEvent => 1})

      assert_span_stop!(@playbook_run_event, %{
        state: :failed,
        server_id: server.id,
        playbook: pending.playbook
      })
    end

    test "interrupts the run when the server is offline", %{server: server} do
      pending = pending_run(server)
      expected_server = pending.server
      cause = cause()
      interrupted = %{pending | state: :interrupted, finished_at: @now, updated_at: @now}

      existing = fetch_new_stored_events()
      previous_counts = count_rows(@affected_tables)

      expect(ServerManagerClientMock, :online?, fn ^expected_server -> false end)

      assert AnsiblePipelineRunner.process_event({:run_playbook, pending.id, cause}) == :ok

      assert Repo.get!(AnsiblePlaybookRun, pending.id) ==
               %{interrupted | server: not_loaded(:server, AnsiblePlaybookRun)}

      assert_run_finished_event(interrupted, server, cause, existing)
      assert_row_count_diff(previous_counts, %{StoredEvent => 1})

      # The interrupted path emits a plain telemetry event (not a span), whose
      # duration is derived from the pinned timestamps and so is fully knowable.
      assert assert_telemetry_event!(@playbook_run_interrupted_event) == %{
               measurements: %{duration: AnsiblePlaybookRun.duration(interrupted)},
               metadata: %{state: :interrupted, server_id: server.id, playbook: pending.playbook},
               config: nil
             }
    end
  end

  # A `:telemetry.span/3` stop event: its `duration`/`monotonic_time`
  # measurements and the `telemetry_span_context` reference are not knowable in
  # advance, so they are bound from the received event and the whole value —
  # including the deterministic metadata and those unknowable parts — is
  # asserted by equality.
  defp assert_span_stop!(event, metadata) do
    data = assert_telemetry_event!(event ++ [:stop])

    assert data == %{
             measurements: %{
               duration: data.measurements.duration,
               monotonic_time: data.measurements.monotonic_time
             },
             metadata:
               Map.put(metadata, :telemetry_span_context, data.metadata.telemetry_span_context),
             config: nil
           }
  end

  # `start_running` is the transition the runner commits before streaming; build
  # the expected running row the same way (the runner stamps `Clock.now/0`).
  defp start_running(pending),
    do: %{pending | state: :running, started_at: @now, updated_at: @now}

  defp assert_run_running_event(run, server, cause, existing) do
    assert [%StoredEvent{id: event_id} = event] = fetch_new_stored_events(existing)

    assert event ==
             %StoredEvent{
               __meta__: loaded(StoredEvent, "events"),
               id: event_id,
               stream: "servers:servers:#{server.id}",
               version: server.version,
               type: "archidep/servers/ansible-playbook-run-running",
               data: %{
                 "id" => run.id,
                 "playbook" => run.playbook,
                 "host" => host_string(run),
                 "port" => run.port,
                 "user" => run.user,
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
  end

  defp assert_run_finished_event(run, server, cause, existing) do
    assert [%StoredEvent{id: event_id} = event] = fetch_new_stored_events(existing)

    assert event ==
             %StoredEvent{
               __meta__: loaded(StoredEvent, "events"),
               id: event_id,
               stream: "servers:servers:#{server.id}",
               version: server.version,
               type: "archidep/servers/ansible-playbook-run-finished",
               data: %{
                 "id" => run.id,
                 "playbook" => run.playbook,
                 "host" => host_string(run),
                 "port" => run.port,
                 "user" => run.user,
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
