defmodule ArchiDep.Servers.ReadAnsibleTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox
  alias ArchiDep.Errors.UnauthorizedError
  alias ArchiDep.PubSub.Scope
  alias ArchiDep.Servers.Behaviour
  alias ArchiDep.Servers.Context
  alias ArchiDep.Servers.ContextMock
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookEvent
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Support.Factory
  alias ArchiDep.Support.ServersFactory
  alias ArchiDep.Support.ServersTestHelpers
  alias ArchiDep.TrackerClientMock
  alias Ecto.UUID
  alias Phoenix.PubSub

  # A fixed past instant for the persisted server/run/event fixtures.
  @past ~U[2023-09-15 09:42:17.000000Z]

  setup :verify_on_exit!

  setup_all do
    %{
      fetch_ansible_playbook_runs: protect({Context, :fetch_ansible_playbook_runs, 1}, Behaviour),
      fetch_ansible_playbook_run: protect({Context, :fetch_ansible_playbook_run, 2}, Behaviour),
      fetch_ansible_playbook_events_for_run:
        protect({Context, :fetch_ansible_playbook_events_for_run, 2}, Behaviour),
      subscribe_ansible_playbook_runs:
        protect({Context, :subscribe_ansible_playbook_runs, 0}, Behaviour),
      tracked_ansible_playbook_runs:
        protect({Context, :tracked_ansible_playbook_runs, 0}, Behaviour),
      refresh_ansible_playbook_runs:
        protect({Context, :refresh_ansible_playbook_runs, 4}, Behaviour)
    }
  end

  describe "fetch_ansible_playbook_runs/1" do
    test "lists every run ordered by creation time (newest first) for a root user", %{
      fetch_ansible_playbook_runs: fetch_ansible_playbook_runs
    } do
      %{owner: owner, class: class} = ServersTestHelpers.register_group_member(@past)
      server = ServersTestHelpers.insert_server(owner.id, class.id)

      # Inserted oldest-first to prove the query sorts rather than returning
      # insertion order.
      older =
        ServersFactory.insert(:ansible_playbook_run,
          server_id: server.id,
          created_at: DateTime.add(@past, -2, :hour)
        )

      newer =
        ServersFactory.insert(:ansible_playbook_run, server_id: server.id, created_at: @past)

      root = Factory.build(:authentication, root: true)

      assert fetch_ansible_playbook_runs.(root) == [run_view(newer.id), run_view(older.id)]

      assert_no_stored_events!()
    end

    test "denies a non-root user", %{fetch_ansible_playbook_runs: fetch_ansible_playbook_runs} do
      %{auth: auth} = ServersTestHelpers.register_group_member(@past)

      assert_raise UnauthorizedError, fn -> fetch_ansible_playbook_runs.(auth) end

      assert_no_stored_events!()
    end
  end

  describe "fetch_ansible_playbook_run/2" do
    test "fetches a run with its server graph for a root user", %{
      fetch_ansible_playbook_run: fetch_ansible_playbook_run
    } do
      %{owner: owner, class: class} = ServersTestHelpers.register_group_member(@past)
      server = ServersTestHelpers.insert_server(owner.id, class.id)
      run = ServersFactory.insert(:ansible_playbook_run, server_id: server.id, created_at: @past)

      root = Factory.build(:authentication, root: true)

      assert fetch_ansible_playbook_run.(root, run.id) == {:ok, deep_run_view(run.id)}

      assert_no_stored_events!()
    end

    test "returns not-found for an unknown run id", %{
      fetch_ansible_playbook_run: fetch_ansible_playbook_run
    } do
      root = Factory.build(:authentication, root: true)

      assert fetch_ansible_playbook_run.(root, UUID.generate()) ==
               {:error, :ansible_playbook_run_not_found}

      assert_no_stored_events!()
    end

    test "masks an existing run as not-found for a non-root user", %{
      fetch_ansible_playbook_run: fetch_ansible_playbook_run
    } do
      %{owner: owner, class: class} = ServersTestHelpers.register_group_member(@past)
      server = ServersTestHelpers.insert_server(owner.id, class.id)
      run = ServersFactory.insert(:ansible_playbook_run, server_id: server.id, created_at: @past)

      %{auth: auth} = ServersTestHelpers.register_group_member(@past)

      assert fetch_ansible_playbook_run.(auth, run.id) ==
               {:error, :ansible_playbook_run_not_found}

      assert_no_stored_events!()
    end
  end

  describe "fetch_ansible_playbook_events_for_run/2" do
    test "lists a run's events ordered by occurrence (newest first) for a root user", %{
      fetch_ansible_playbook_events_for_run: fetch_ansible_playbook_events_for_run
    } do
      %{owner: owner, class: class} = ServersTestHelpers.register_group_member(@past)
      server = ServersTestHelpers.insert_server(owner.id, class.id)
      run = ServersFactory.insert(:ansible_playbook_run, server_id: server.id, created_at: @past)

      # Inserted oldest-first, with a `run` left unloaded so the persisted row
      # matches what the un-preloaded query reads back.
      older =
        ServersFactory.insert(:ansible_playbook_event,
          run: not_loaded(:run, AnsiblePlaybookEvent),
          run_id: run.id,
          occurred_at: DateTime.add(@past, -1, :hour)
        )

      newer =
        ServersFactory.insert(:ansible_playbook_event,
          run: not_loaded(:run, AnsiblePlaybookEvent),
          run_id: run.id,
          occurred_at: @past
        )

      # An event of another run must be excluded.
      other_run =
        ServersFactory.insert(:ansible_playbook_run, server_id: server.id, created_at: @past)

      ServersFactory.insert(:ansible_playbook_event,
        run: not_loaded(:run, AnsiblePlaybookEvent),
        run_id: other_run.id,
        occurred_at: @past
      )

      root = Factory.build(:authentication, root: true)

      assert fetch_ansible_playbook_events_for_run.(root, run.id) == {:ok, [newer, older]}

      assert_no_stored_events!()
    end

    test "returns not-found for an unknown run id", %{
      fetch_ansible_playbook_events_for_run: fetch_ansible_playbook_events_for_run
    } do
      root = Factory.build(:authentication, root: true)

      assert fetch_ansible_playbook_events_for_run.(root, UUID.generate()) ==
               {:error, :ansible_playbook_run_not_found}

      assert_no_stored_events!()
    end

    test "masks an existing run's events as not-found for a non-root user", %{
      fetch_ansible_playbook_events_for_run: fetch_ansible_playbook_events_for_run
    } do
      %{owner: owner, class: class} = ServersTestHelpers.register_group_member(@past)
      server = ServersTestHelpers.insert_server(owner.id, class.id)
      run = ServersFactory.insert(:ansible_playbook_run, server_id: server.id, created_at: @past)

      ServersFactory.insert(:ansible_playbook_event,
        run: not_loaded(:run, AnsiblePlaybookEvent),
        run_id: run.id,
        occurred_at: @past
      )

      %{auth: auth} = ServersTestHelpers.register_group_member(@past)

      assert fetch_ansible_playbook_events_for_run.(auth, run.id) ==
               {:error, :ansible_playbook_run_not_found}

      assert_no_stored_events!()
    end
  end

  describe "subscribe_ansible_playbook_runs/0" do
    test "delivers the ansible pipeline's playbook tracking presence", %{
      subscribe_ansible_playbook_runs: subscribe_ansible_playbook_runs
    } do
      assert subscribe_ansible_playbook_runs.() == :ok

      run_id = UUID.generate()
      meta = playbook_meta(state: :running, events: 2, current_task: "Gathering facts")
      message = {:update, "playbook:#{run_id}", meta}

      :ok =
        PubSub.broadcast(
          ArchiDep.PubSub,
          "tracker:" <> Scope.global_topic("ansible-queue"),
          message
        )

      assert_receive ^message

      assert_no_stored_events!()
    end
  end

  describe "tracked_ansible_playbook_runs/0" do
    test "returns the running playbooks' progress keyed by run id, ignoring other entries", %{
      tracked_ansible_playbook_runs: tracked_ansible_playbook_runs
    } do
      ansible_queue_topic = Scope.global_topic("ansible-queue")
      run_id = UUID.generate()
      meta = playbook_meta(state: :running, events: 3, current_task: "Installing packages")

      # The tracker topic also carries the queue counters and fact-gathering
      # entries; only the playbook entries make up the progress map.
      expect(TrackerClientMock, :list, fn ^ansible_queue_topic ->
        [
          {"queue:default", %{demand: 0, pending: 0}},
          {"gather-facts:#{UUID.generate()}", %{type: :gather_facts}},
          {"playbook:#{run_id}", meta}
        ]
      end)

      assert tracked_ansible_playbook_runs.() == %{run_id => meta}

      assert_no_stored_events!()
    end
  end

  describe "refresh_ansible_playbook_runs/4" do
    test "updates a tracked run in place and records its progress", %{
      refresh_ansible_playbook_runs: refresh_ansible_playbook_runs
    } do
      auth = Factory.build(:authentication, root: true)
      %AnsiblePlaybookRun{} = run = build_run(state: :running, number_of_events: 1)
      other = build_run(state: :running, number_of_events: 4)
      meta = playbook_meta(state: :succeeded, events: 7, current_task: nil)

      # `other` must pass through untouched so the merge is proven to target the
      # referenced run rather than every run in the list.
      assert refresh_ansible_playbook_runs.(
               auth,
               [run, other],
               %{},
               {:update, "playbook:#{run.id}", meta}
             ) ==
               {:ok, [%AnsiblePlaybookRun{run | state: :succeeded, number_of_events: 7}, other],
                %{run.id => meta}}

      assert_no_stored_events!()
    end

    test "keeps the newer tracked progress when a stale update arrives", %{
      refresh_ansible_playbook_runs: refresh_ansible_playbook_runs
    } do
      auth = Factory.build(:authentication, root: true)
      run = build_run(state: :succeeded, number_of_events: 7)
      current = playbook_meta(state: :succeeded, events: 7, current_task: nil)
      stale = playbook_meta(state: :running, events: 3, current_task: "Rolling back")

      assert refresh_ansible_playbook_runs.(
               auth,
               [run],
               %{run.id => current},
               {:update, "playbook:#{run.id}", stale}
             ) == {:ok, [run], %{run.id => current}}

      assert_no_stored_events!()
    end

    test "fetches a newly tracked run and inserts it in chronological order", %{
      refresh_ansible_playbook_runs: refresh_ansible_playbook_runs
    } do
      auth = Factory.build(:authentication, root: true)

      newest = build_run(created_at: ~U[2026-06-20 11:55:00Z])
      oldest = build_run(created_at: ~U[2026-06-20 11:00:00Z])
      joining = build_run(created_at: ~U[2026-06-20 11:30:00Z])
      joining_id = joining.id
      meta = playbook_meta(state: :succeeded, events: 2, current_task: nil)

      expect(ContextMock, :fetch_ansible_playbook_run, fn ^auth, ^joining_id ->
        {:ok, joining}
      end)

      assert refresh_ansible_playbook_runs.(
               auth,
               [newest, oldest],
               %{},
               {:join, "playbook:#{joining_id}", meta}
             ) == {:ok, [newest, joining, oldest], %{joining_id => meta}}

      assert_no_stored_events!()
    end

    test "records tracking but leaves the list unchanged when the joined run cannot be fetched",
         %{refresh_ansible_playbook_runs: refresh_ansible_playbook_runs} do
      auth = Factory.build(:authentication, root: true)
      existing = build_run()
      joining_id = UUID.generate()
      meta = playbook_meta(state: :running, events: 1, current_task: "Connecting")

      expect(ContextMock, :fetch_ansible_playbook_run, fn ^auth, ^joining_id ->
        {:error, :ansible_playbook_run_not_found}
      end)

      assert refresh_ansible_playbook_runs.(
               auth,
               [existing],
               %{},
               {:join, "playbook:#{joining_id}", meta}
             ) == {:ok, [existing], %{joining_id => meta}}

      assert_no_stored_events!()
    end

    test "re-fetches the persisted run and drops its tracking when it leaves", %{
      refresh_ansible_playbook_runs: refresh_ansible_playbook_runs
    } do
      auth = Factory.build(:authentication, root: true)
      run_id = UUID.generate()

      tracked_run = build_run(id: run_id, state: :running, number_of_events: 3)
      finished = build_run(id: run_id, state: :succeeded, number_of_events: 9)

      expect(ContextMock, :fetch_ansible_playbook_run, fn ^auth, ^run_id -> {:ok, finished} end)

      assert refresh_ansible_playbook_runs.(
               auth,
               [tracked_run],
               %{run_id => playbook_meta(state: :running, events: 3, current_task: "Finishing")},
               {:leave, "playbook:#{run_id}", %{}}
             ) == {:ok, [finished], %{}}

      assert_no_stored_events!()
    end

    test "keeps the last-known run when a leaving run can no longer be fetched", %{
      refresh_ansible_playbook_runs: refresh_ansible_playbook_runs
    } do
      auth = Factory.build(:authentication, root: true)
      run_id = UUID.generate()
      tracked_run = build_run(id: run_id)

      expect(ContextMock, :fetch_ansible_playbook_run, fn ^auth, ^run_id ->
        {:error, :ansible_playbook_run_not_found}
      end)

      assert refresh_ansible_playbook_runs.(
               auth,
               [tracked_run],
               %{run_id => playbook_meta()},
               {:leave, "playbook:#{run_id}", %{}}
             ) == {:ok, [tracked_run], %{}}

      assert_no_stored_events!()
    end

    test "ignores messages that do not concern a playbook run", %{
      refresh_ansible_playbook_runs: refresh_ansible_playbook_runs
    } do
      auth = Factory.build(:authentication, root: true)
      run = build_run()

      assert refresh_ansible_playbook_runs.(
               auth,
               [run],
               %{},
               {:join, "queue:default", %{demand: 0, pending: 0}}
             ) == :ignore

      assert_no_stored_events!()
    end
  end

  defp playbook_meta(overrides \\ []),
    do: Enum.into(overrides, %{type: :playbook, state: :running, events: 1, current_task: nil})

  # A run as the page holds it: its server preloaded, which the reconciled list
  # type requires.
  defp build_run(overrides \\ []),
    do:
      ServersFactory.build(
        :ansible_playbook_run,
        [server: ServersFactory.build(:server)] ++ overrides
      )

  # A run read back as `fetch_ansible_playbook_runs/0` returns it: the run with
  # only its server preloaded (nothing under the server).
  defp run_view(id),
    do: AnsiblePlaybookRun |> Repo.get!(id) |> Repo.preload(:server)

  # A run read back as `fetch_ansible_playbook_run/1` returns it: the server and
  # its group, owner, and the owner's own group member and group preloaded.
  defp deep_run_view(id),
    do:
      AnsiblePlaybookRun
      |> Repo.get!(id)
      |> Repo.preload(server: [:group, owner: [group_member: :group]])
end
