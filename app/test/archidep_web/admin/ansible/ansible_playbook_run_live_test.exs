defmodule ArchiDepWeb.Admin.Ansible.AnsiblePlaybookRunLiveTest do
  use ArchiDepWeb.Support.LiveCase, async: true

  import ArchiDep.Support.DataCase, only: [not_loaded: 2]
  import Hammox
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookEvent
  alias ArchiDep.Support.ServersFactory

  setup :verify_on_exit!

  describe "as a root user" do
    setup :register_and_log_in_root

    setup do
      Hammox.stub(ArchiDep.Clock.Mock, :now, fn -> ~U[2026-06-20 12:00:00Z] end)
      :ok
    end

    test "renders a finished playbook run with its events", %{conn: conn, auth: auth} do
      server = ServersFactory.build(:server, username: "alice-vm")

      run =
        ServersFactory.build(:ansible_playbook_run,
          playbook: "site.yml",
          playbook_path: "/playbooks/site.yml",
          playbook_digest: <<0xAB, 0xCD>>,
          git_revision: "abcdef1234567",
          host: %Postgrex.INET{address: {10, 0, 0, 1}, netmask: nil},
          port: 22,
          user: "ansible",
          vars: %{"app_user_name" => "alice", "ssh_password" => "s3cret"},
          server: server,
          state: :succeeded,
          exit_code: 0,
          number_of_events: 2,
          created_at: ~U[2026-06-20 11:30:00Z],
          finished_at: ~U[2026-06-20 11:45:00Z],
          stats_changed: 3,
          stats_failures: 0,
          stats_ignored: 0,
          stats_ok: 5,
          stats_rescued: 0,
          stats_skipped: 0,
          stats_unreachable: 0
        )

      events = [
        ServersFactory.build(:ansible_playbook_event,
          run: not_loaded(:run, AnsiblePlaybookEvent),
          run_id: run.id,
          name: "task-changed",
          task_name: "Install packages",
          task_id: "task-1",
          action: "apt",
          changed: true,
          occurred_at: ~U[2026-06-20 11:31:00Z],
          data: %{"pkg" => "nginx"}
        ),
        ServersFactory.build(:ansible_playbook_event,
          run: not_loaded(:run, AnsiblePlaybookEvent),
          run_id: run.id,
          name: "task-ok",
          task_name: nil,
          task_id: nil,
          action: nil,
          changed: false,
          occurred_at: ~U[2026-06-20 11:32:00Z],
          data: %{}
        )
      ]

      stub_run(auth, run)

      expect(Servers.ContextMock, :fetch_ansible_playbook_events_for_run, 1, fn ^auth, run_id ->
        assert run_id == run.id
        {:ok, events}
      end)

      {:ok, view, static_html} = live(conn, "/admin/ansible/playbook-runs/#{run.id}")

      assert_html_title(static_html, "Ansible · Admin · ArchiDep")

      assert page_projection(render_async(view)) == %{
               heading: "site.yml playbook run for alice-vm",
               data_display: [
                 {"Playbook",
                  "Relative path /playbooks/site.yml site.yml Digest abcd Git revision abcdef1234567 @ abcdef1"},
                 {"Connection", "ansible@10.0.0.1:22"},
                 {"Server", {"alice-vm", "/admin/servers/#{run.server_id}"}},
                 {"Started", "30 minutes ago"},
                 {"Duration", "15 minutes"},
                 {"State", "Succeeded"},
                 {"Exit code", "0"},
                 {"Events", "2"},
                 {"Tasks", "3 changed 5 ok"}
               ],
               variables: [
                 {"app_user_name", :visible, "alice"},
                 {"ssh_password", :hidden, "s3cret"}
               ],
               events: [
                 {"11:31:00", "task-changed", "Task ID task-1 Install packages", "apt", "yes"},
                 {"11:32:00", "task-ok", "-", "-", "no"}
               ]
             }
    end

    test "renders a pending run with no exit code and no events yet", %{conn: conn, auth: auth} do
      server = ServersFactory.build(:server, username: "bob-vm")

      run =
        ServersFactory.build(:ansible_playbook_run,
          playbook: "bootstrap.yml",
          playbook_path: "/playbooks/bootstrap.yml",
          playbook_digest: <<0x01>>,
          git_revision: "0123456789",
          host: %Postgrex.INET{address: {192, 168, 1, 5}, netmask: nil},
          port: 2222,
          user: "root",
          vars: %{},
          server: server,
          state: :pending,
          exit_code: nil,
          number_of_events: 0,
          started_at: nil,
          finished_at: nil,
          created_at: ~U[2026-06-20 11:59:00Z],
          stats_changed: 0,
          stats_failures: 0,
          stats_ignored: 0,
          stats_ok: 0,
          stats_rescued: 0,
          stats_skipped: 0,
          stats_unreachable: 0
        )

      stub_run(auth, run)

      expect(Servers.ContextMock, :fetch_ansible_playbook_events_for_run, 1, fn ^auth, _run_id ->
        {:ok, []}
      end)

      {:ok, view, _static_html} = live(conn, "/admin/ansible/playbook-runs/#{run.id}")

      assert page_projection(render_async(view)) == %{
               heading: "bootstrap.yml playbook run for bob-vm",
               data_display: [
                 {"Playbook",
                  "Relative path /playbooks/bootstrap.yml bootstrap.yml Digest 01 Git revision 0123456789 @ 0123456"},
                 {"Connection", "root@192.168.1.5:2222"},
                 {"Server", {"bob-vm", "/admin/servers/#{run.server_id}"}},
                 {"Started", "1 minute ago"},
                 {"Duration", "1 minute"},
                 {"State", "Pending"},
                 {"Exit code", "N/A"},
                 {"Events", "0"},
                 {"Tasks", "N/A"}
               ],
               variables: [],
               events: []
             }
    end

    test "redirects to the ansible page when the run is not found", %{conn: conn, auth: auth} do
      stub(Servers.ContextMock, :fetch_ansible_playbook_run, fn ^auth, _run_id ->
        {:error, :ansible_playbook_run_not_found}
      end)

      assert {:error, {:live_redirect, %{flash: flash, to: "/admin/ansible"}}} =
               live(conn, "/admin/ansible/playbook-runs/#{UUID.generate()}")

      assert redirect_notifications(flash) == [
               {:error, gettext("Ansible playbook run not found")}
             ]
    end
  end

  test "accessing a playbook run redirects to the login page without authentication", %{
    conn: conn
  } do
    assert_live_anonymous_user_redirected_to_login(
      conn,
      "/admin/ansible/playbook-runs/#{UUID.generate()}"
    )
  end

  # The page reads the run on both the disconnected and connected mounts.
  defp stub_run(auth, run) do
    id = run.id
    stub(Servers.ContextMock, :fetch_ansible_playbook_run, fn ^auth, ^id -> {:ok, run} end)
  end

  defp page_projection(html) do
    %{
      heading: html |> find_html_elements("h2") |> hd() |> html_element_text(),
      data_display: data_display_rows(html),
      variables: variable_rows(html),
      events: event_rows(html)
    }
  end

  # The Playbook row nests its own data_display inside tooltips, so a row can hold
  # more than one dt/dd; the row's own pair is the first in document order.
  defp data_display_rows(html) do
    html
    |> find_html_elements("dl.mt-4 > div")
    |> Enum.map(fn row ->
      title = row |> find_html_elements("dt") |> hd() |> html_element_text()
      dd = row |> find_html_elements("dd") |> hd()
      {title, dd_value(dd)}
    end)
  end

  defp dd_value(dd) do
    case find_html_elements(dd, "a") do
      [link] -> {html_element_text(dd), html_element_attribute(link, "href")}
      [] -> html_element_text(dd)
    end
  end

  defp variable_rows(html) do
    [variables_table, _events_table] = find_html_elements(html, "table")

    variables_table
    |> find_html_elements("tbody tr")
    |> Enum.map(fn row ->
      [key] = row |> find_html_elements("th") |> Enum.map(&html_element_text/1)
      [pre] = find_html_elements(row, "pre")
      masked = find_html_elements(row, "span.font-mono") != []
      {key, if(masked, do: :hidden, else: :visible), html_element_text(pre)}
    end)
  end

  defp event_rows(html) do
    [_variables_table, events_table] = find_html_elements(html, "table")

    events_table
    |> find_html_elements("tbody tr")
    |> Enum.filter(fn row -> find_html_elements(row, "th") != [] end)
    |> Enum.map(fn row ->
      [time] = row |> find_html_elements("td:nth-child(1)") |> Enum.map(&html_element_text/1)
      [name] = row |> find_html_elements("th") |> Enum.map(&html_element_text/1)
      [task] = row |> find_html_elements("td:nth-child(3)") |> Enum.map(&html_element_text/1)
      [action] = row |> find_html_elements("td:nth-child(4)") |> Enum.map(&html_element_text/1)
      [changed] = row |> find_html_elements("td:nth-child(5)") |> Enum.map(&html_element_text/1)
      {time, name, task, action, changed}
    end)
  end

  defp redirect_notifications(flash),
    do:
      flash
      |> Map.values()
      |> Enum.map(fn notification -> {notification.type, notification.message} end)
end
