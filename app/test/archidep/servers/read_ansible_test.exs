defmodule ArchiDep.Servers.ReadAnsibleTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox
  alias ArchiDep.Errors.UnauthorizedError
  alias ArchiDep.Servers.Behaviour
  alias ArchiDep.Servers.Context
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookEvent
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Support.Factory
  alias ArchiDep.Support.ServersFactory
  alias ArchiDep.Support.ServersTestHelpers
  alias Ecto.UUID

  # A fixed past instant for the persisted server/run/event fixtures.
  @past ~U[2023-09-15 09:42:17.000000Z]

  setup :verify_on_exit!

  setup_all do
    %{
      fetch_ansible_playbook_runs: protect({Context, :fetch_ansible_playbook_runs, 1}, Behaviour),
      fetch_ansible_playbook_run: protect({Context, :fetch_ansible_playbook_run, 2}, Behaviour),
      fetch_ansible_playbook_events_for_run:
        protect({Context, :fetch_ansible_playbook_events_for_run, 2}, Behaviour)
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
