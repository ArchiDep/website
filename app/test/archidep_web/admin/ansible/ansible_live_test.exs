defmodule ArchiDepWeb.Admin.Ansible.AnsibleLiveTest do
  use ArchiDepWeb.Support.LiveCase, async: true

  import Hammox
  alias ArchiDep.PubSub.Scope
  alias ArchiDep.Servers
  alias ArchiDep.Support.ServersFactory
  alias ArchiDep.TrackerClientMock

  @path "/admin/ansible"
  @now ~U[2026-06-20 12:00:00Z]

  setup :verify_on_exit!

  describe "as a root user" do
    setup :register_and_log_in_root

    setup do
      Hammox.stub(ArchiDep.Clock.Mock, :now, fn -> @now end)
      :ok
    end

    test "renders the list of playbook runs with their stats", %{conn: conn, auth: auth} do
      runs = [running_run(), succeeded_run(), failed_run()]
      stub_runs(auth, runs)
      stub_tracking([])

      {:ok, _view, html} = live(conn, @path)

      assert_html_title(html, "Ansible · Admin · ArchiDep")

      assert run_rows(html) == [
               {"site.yml", "5 minutes ago", "5 minutes", "Running", "1", "1 ok"},
               {"bootstrap.yml", "30 minutes ago", "15 minutes", "Succeeded", "2",
                "3 changed 5 ok"},
               {"teardown.yml", "1 hour ago", "10 minutes", "exit code 2 Failed", "4", "2 failed"}
             ]
    end

    test "renders an empty state when no playbook has been run", %{conn: conn, auth: auth} do
      stub_runs(auth, [])
      stub_tracking([])

      {:ok, _view, html} = live(conn, @path)

      assert run_rows(html) == []
      assert empty_state(html) == ["No Ansible playbook have been run"]
    end

    test "overlays the current task of a tracked, in-progress run", %{conn: conn, auth: auth} do
      run = running_run()
      stub_runs(auth, [run])

      # Non-playbook tracker entries (the queue counters, fact-gathering) are
      # filtered out; only the playbook entry overlays its current task.
      stub_tracking([
        {"queue:default", %{demand: 0, pending: 0}},
        {"playbook:#{run.id}",
         %{type: :playbook, state: :running, events: 1, current_task: "Gathering facts"}}
      ])

      {:ok, _view, html} = live(conn, @path)

      assert run_rows(html) == [
               {"site.yml", "5 minutes ago", "5 minutes", "Running", "1", "Gathering facts..."}
             ]
    end

    test "adds a newly tracked run that joins the queue", %{conn: conn, auth: auth} do
      existing = succeeded_run()
      stub_runs(auth, [existing])
      stub_tracking([])

      joining = running_run()
      run_id = joining.id

      expect(Servers.ContextMock, :fetch_ansible_playbook_run, 1, fn ^auth, ^run_id ->
        {:ok, joining}
      end)

      {:ok, view, _html} = live(conn, @path)

      send(
        view.pid,
        {:join, "playbook:#{run_id}",
         %{type: :playbook, state: :running, events: 1, current_task: "Connecting"}}
      )

      wait_for_socket_assigns!(
        view,
        fn assigns -> Map.has_key?(assigns.tracked_playbooks, run_id) end,
        "run joined the queue"
      )

      assert run_rows(render(view)) == [
               {"site.yml", "5 minutes ago", "5 minutes", "Running", "1", "Connecting..."},
               {"bootstrap.yml", "30 minutes ago", "15 minutes", "Succeeded", "2",
                "3 changed 5 ok"}
             ]
    end

    test "inserts a joining run in chronological order among existing runs", %{
      conn: conn,
      auth: auth
    } do
      newest = running_run()
      oldest = failed_run()
      stub_runs(auth, [newest, oldest])
      stub_tracking([])

      # The joining run was created between the two already shown, so it must be
      # placed in the middle, not prepended or appended.
      joining = succeeded_run()
      run_id = joining.id

      expect(Servers.ContextMock, :fetch_ansible_playbook_run, 1, fn ^auth, ^run_id ->
        {:ok, joining}
      end)

      {:ok, view, _html} = live(conn, @path)

      send(
        view.pid,
        {:join, "playbook:#{run_id}",
         %{type: :playbook, state: :succeeded, events: 2, current_task: nil}}
      )

      wait_for_socket_assigns!(
        view,
        fn assigns -> Map.has_key?(assigns.tracked_playbooks, run_id) end,
        "run joined the queue"
      )

      assert run_rows(render(view)) == [
               {"site.yml", "5 minutes ago", "5 minutes", "Running", "1", "1 ok"},
               {"bootstrap.yml", "30 minutes ago", "15 minutes", "Succeeded", "2", "-"},
               {"teardown.yml", "1 hour ago", "10 minutes", "exit code 2 Failed", "4", "2 failed"}
             ]
    end

    test "updates a tracked run in place, then restores it when tracking leaves", %{
      conn: conn,
      auth: auth
    } do
      run = running_run()
      stub_runs(auth, [run])
      stub_tracking([])

      run_id = run.id

      {:ok, view, _html} = live(conn, @path)

      send(
        view.pid,
        {:update, "playbook:#{run_id}",
         %{type: :playbook, state: :succeeded, events: 7, current_task: nil}}
      )

      wait_for_socket_assigns!(
        view,
        fn assigns -> Map.has_key?(assigns.tracked_playbooks, run_id) end,
        "run tracked"
      )

      assert run_rows(render(view)) == [
               {"site.yml", "5 minutes ago", "5 minutes", "Succeeded", "7", "-"}
             ]

      # When tracking leaves, the row is rebuilt from the freshly fetched run.
      finished = succeeded_run(id: run_id, playbook: "site.yml")

      expect(Servers.ContextMock, :fetch_ansible_playbook_run, 1, fn ^auth, ^run_id ->
        {:ok, finished}
      end)

      send(view.pid, {:leave, "playbook:#{run_id}", %{}})

      wait_for_socket_assigns!(
        view,
        fn assigns -> not Map.has_key?(assigns.tracked_playbooks, run_id) end,
        "run left the queue"
      )

      assert run_rows(render(view)) == [
               {"site.yml", "30 minutes ago", "15 minutes", "Succeeded", "2", "3 changed 5 ok"}
             ]
    end
  end

  test "accessing the ansible page redirects to the login page without authentication", %{
    conn: conn
  } do
    assert_live_anonymous_user_redirected_to_login(conn, @path)
  end

  defp running_run(overrides \\ []),
    do:
      build_run(
        [
          playbook: "site.yml",
          state: :running,
          exit_code: nil,
          number_of_events: 1,
          created_at: ~U[2026-06-20 11:55:00Z],
          finished_at: nil,
          stats_ok: 1
        ] ++ overrides
      )

  defp succeeded_run(overrides \\ []),
    do:
      build_run(
        [
          playbook: "bootstrap.yml",
          state: :succeeded,
          exit_code: 0,
          number_of_events: 2,
          created_at: ~U[2026-06-20 11:30:00Z],
          finished_at: ~U[2026-06-20 11:45:00Z],
          stats_changed: 3,
          stats_ok: 5
        ] ++ overrides
      )

  defp failed_run(overrides \\ []),
    do:
      build_run(
        [
          playbook: "teardown.yml",
          state: :failed,
          exit_code: 2,
          number_of_events: 4,
          created_at: ~U[2026-06-20 11:00:00Z],
          finished_at: ~U[2026-06-20 11:10:00Z],
          stats_failures: 2
        ] ++ overrides
      )

  @zero_stats [
    stats_changed: 0,
    stats_failures: 0,
    stats_ignored: 0,
    stats_ok: 0,
    stats_rescued: 0,
    stats_skipped: 0,
    stats_unreachable: 0
  ]

  # Mirrors production: the read preloads the run's server.
  defp build_run(overrides) do
    defaults = [server: ServersFactory.build(:server)] ++ @zero_stats
    ServersFactory.build(:ansible_playbook_run, Map.new(Keyword.merge(defaults, overrides)))
  end

  # The page reads the runs on both the disconnected and connected mounts.
  defp stub_runs(auth, runs),
    do: stub(Servers.ContextMock, :fetch_ansible_playbook_runs, fn ^auth -> runs end)

  # The tracker presence list is read once, on the connected mount only.
  defp stub_tracking(entries) do
    ansible_queue_topic = Scope.global_topic("ansible-queue")
    expect(TrackerClientMock, :list, 1, fn ^ansible_queue_topic -> entries end)
  end

  defp run_rows(html) do
    html
    |> find_html_elements(~s(tbody tr[id^="ansible-playbook-run-"]))
    |> Enum.map(fn row ->
      [playbook, start, duration, state, events, tasks] =
        Enum.map(1..6, fn n ->
          [cell] = find_html_elements(row, "td:nth-child(#{n})")
          html_element_text(cell)
        end)

      {playbook, start, duration, state, events, tasks}
    end)
  end

  defp empty_state(html),
    do: html |> find_html_elements("tbody tr td .italic") |> Enum.map(&html_element_text/1)
end
