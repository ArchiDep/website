defmodule ArchiDep.Servers.Ansible.ContextTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox
  alias ArchiDep.Clock
  alias ArchiDep.Servers.Ansible.Context
  alias ArchiDep.Servers.Ansible.PlaybooksRegistry
  alias ArchiDep.Servers.Ansible.RunnerClientMock
  alias ArchiDep.Servers.Ansible.Tracker
  alias ArchiDep.Servers.Schemas.AnsiblePlaybook
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookEvent
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Support.EventsFactory
  alias ArchiDep.Support.ServersFactory
  alias ArchiDep.Support.ServersTestHelpers

  # The tracker stamps every timestamp from `Clock.now/0`, so a fixed instant
  # makes the persisted run, event and stored events deterministic.
  @now ~U[2024-03-15 10:30:00.000000Z]
  # A safely-past instant for the persisted owner/group/server graph.
  @past ~U[2024-01-01 00:00:00.000000Z]

  @user "deploy"
  @vars %{"ansible_connection" => "ssh", "ansible_user" => "deploy"}
  @vars_digest "vars-digest"

  # Everything running a playbook through the tracker can write to.
  @affected_tables [AnsiblePlaybookRun, AnsiblePlaybookEvent, StoredEvent]

  setup :verify_on_exit!

  setup do
    stub(Clock.Mock, :now, fn -> @now end)
    :ok
  end

  describe "gather_facts/2" do
    test "gathers facts for the server's address and SSH port through the runner" do
      server = ServersFactory.build(:server, ssh_port: 2222)
      facts = %{"os" => "linux"}
      test_pid = self()

      expect(RunnerClientMock, :gather_facts, fn host, port, user ->
        send(test_pid, {:gather_facts, host, port, user})
        {:ok, facts}
      end)

      assert Context.gather_facts(server, @user) == {:ok, facts}

      assert_received {:gather_facts, host, 2222, @user}
      assert host == server.ip_address.address
    end

    test "defaults the SSH port to 22 when the server has none" do
      server = ServersFactory.build(:server, ssh_port: nil)
      test_pid = self()

      expect(RunnerClientMock, :gather_facts, fn host, port, user ->
        send(test_pid, {:gather_facts, host, port, user})
        {:error, :unreachable}
      end)

      assert Context.gather_facts(server, @user) == {:error, :unreachable}

      assert_received {:gather_facts, host, 22, @user}
      assert host == server.ip_address.address
    end
  end

  describe "run_playbook/3" do
    test "runs each Ansible element through the tracker and yields the tracked results" do
      {run, started_cause} = running_run()
      running_cause = event_reference()
      test_pid = self()

      data = %{
        "_event" => "v2_runner_on_ok",
        "hosts" => %{"archidep" => %{"action" => "command", "changed" => true}}
      }

      expect(RunnerClientMock, :run_playbook, fn playbook_path, host, port, user, vars ->
        send(test_pid, {:run_playbook, playbook_path, host, port, user, vars})
        [{:event, data}, {:exit, {:status, 0}}]
      end)

      previous_counts = count_rows(@affected_tables)

      stream = Context.run_playbook(run, started_cause, running_cause)

      # The runner is invoked eagerly with the host/port/user/vars extracted
      # from the run and the playbook path resolved through the registry.
      assert_received {:run_playbook, playbook_path, host, port, user, vars}
      assert playbook_path == expected_playbook_path("setup")
      assert host == run.host.address
      assert port == run.port
      assert user == run.user
      assert vars == run.vars

      # Enumerating the stream drives each runner element through the tracker.
      assert [{:event, event}, {:succeeded, finished}] = Enum.to_list(stream)

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

      assert finished ==
               %{run | state: :succeeded, exit_code: 0, finished_at: @now, updated_at: @now}

      assert Repo.get!(AnsiblePlaybookEvent, event.id) ==
               %{event | run: not_loaded(:run, AnsiblePlaybookEvent)}

      assert Repo.get!(AnsiblePlaybookRun, run.id) ==
               %{
                 run
                 | server: not_loaded(:server, AnsiblePlaybookRun),
                   number_of_events: 1,
                   last_event_at: @now,
                   state: :succeeded,
                   exit_code: 0,
                   finished_at: @now,
                   updated_at: @now
               }

      assert_row_count_diff(previous_counts, %{AnsiblePlaybookEvent => 1, StoredEvent => 2})
    end
  end

  test "compute the digest of ansible variables" do
    value = %{
      "foo" => [1, :qux, 2, true, 3.14, "string"],
      "bar" => %{baz: true, corge: false},
      "grault" => nil,
      "alice" => ["bob", "dave", "carol"]
    }

    normalized =
      Enum.join(
        [
          "alice",
          "bob",
          "dave",
          "carol",
          "bar",
          "bar.baz",
          "true",
          "bar.corge",
          "false",
          "foo",
          "1",
          "qux",
          "2",
          "true",
          "3.14",
          "string",
          "grault",
          "\0"
        ],
        "\0"
      )

    assert Context.digest_ansible_variables(value) == :crypto.hash(:sha256, normalized)
  end

  defp running_run do
    %{owner: owner, class: class} = ServersTestHelpers.register_group_member(@past)
    server = ServersTestHelpers.insert_server(owner.id, class.id, active: true, ssh_port: 2222)

    {run, started_cause} =
      Tracker.track_playbook!(playbook(), server, @user, @vars, @vars_digest, event_reference())

    {:ok, running} = run |> AnsiblePlaybookRun.start_running(@now) |> Repo.update()
    {running, started_cause}
  end

  defp playbook, do: AnsiblePlaybook.new("playbooks/setup.yml", "playbook-digest")

  # The events table has foreign keys on `causation_id`/`correlation_id`, so a
  # cause must be a real stored event. A factory `stored_event` is a root event
  # (its causation and correlation IDs are its own), which both keys can target.
  defp event_reference, do: :stored_event |> EventsFactory.insert() |> StoredEvent.to_reference()

  defp expected_playbook_path(name),
    do: Path.join(Application.app_dir(:archidep), PlaybooksRegistry.playbook!(name).relative_path)
end
