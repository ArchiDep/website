defmodule ArchiDep.Servers.Schemas.AnsiblePlaybookRunTest do
  use ArchiDep.Support.DataCase, async: true

  alias ArchiDep.Servers.Schemas.AnsiblePlaybook
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.ServersFactory
  alias ArchiDep.Support.ServersTestHelpers
  alias Ecto.Changeset

  # The state-transition builders stamp their timestamps from the `now` they are
  # given, so a fixed instant makes every resulting changeset deterministic.
  @now ~U[2024-03-15 10:30:00.000000Z]
  # A run that started before `@now` keeps `started_at` ordered before the
  # `finished_at` that the terminal transitions stamp at `@now`.
  @before_now ~U[2024-03-15 10:00:00.000000Z]
  # A safely-past instant for the persisted owner/group/server graph the
  # update-query tests run against.
  @past ~U[2024-01-01 00:00:00.000000Z]

  # The tables the update queries can write to, watched by every row-count diff.
  @affected_tables [AnsiblePlaybookRun, StoredEvent]

  describe "new_pending/6" do
    test "builds a pending run from the playbook, server and variables" do
      playbook = AnsiblePlaybook.new("playbooks/setup.yml", "playbook-digest")
      server = ServersFactory.build(:server, ssh_port: 2222)

      changeset =
        AnsiblePlaybookRun.new_pending(
          playbook,
          server,
          "deploy",
          %{"ansible_user" => "deploy"},
          "vars-digest",
          @now
        )

      assert errors_on(changeset) == %{}

      applied = Changeset.apply_changes(changeset)

      assert applied == expected_pending_run(applied, server, %{})
    end

    test "defaults the port to 22 when the server has no SSH port" do
      server = ServersFactory.build(:server, ssh_port: nil)

      changeset =
        AnsiblePlaybookRun.new_pending(
          AnsiblePlaybook.new("playbooks/setup.yml", "playbook-digest"),
          server,
          "deploy",
          %{"ansible_user" => "deploy"},
          "vars-digest",
          @now
        )

      assert errors_on(changeset) == %{}

      applied = Changeset.apply_changes(changeset)

      assert applied == expected_pending_run(applied, server, %{port: 22})
    end

    test "trims the playbook name and user" do
      server = ServersFactory.build(:server, ssh_port: 2222)
      playbook = AnsiblePlaybook.new("playbooks/ setup .yml", "playbook-digest")

      changeset =
        AnsiblePlaybookRun.new_pending(
          playbook,
          server,
          "  deploy  ",
          %{"ansible_user" => "deploy"},
          "vars-digest",
          @now
        )

      assert errors_on(changeset) == %{}

      applied = Changeset.apply_changes(changeset)

      assert applied ==
               expected_pending_run(applied, server, %{playbook_path: "playbooks/ setup .yml"})
    end

    test "the playbook name cannot be longer than 50 characters" do
      playbook = AnsiblePlaybook.new("#{String.duplicate("a", 51)}.yml", "playbook-digest")

      assert errors_on(new_pending(playbook: playbook)) ==
               %{playbook: ["should be at most 50 character(s)"]}
    end

    test "the user cannot be longer than 32 characters" do
      assert errors_on(new_pending(user: String.duplicate("a", 33))) ==
               %{user: ["should be at most 32 character(s)"]}
    end
  end

  describe "start_running/2" do
    test "moves a pending run to the running state and stamps started_at" do
      run = ServersFactory.build(:ansible_playbook_run, state: :pending, started_at: nil)

      changeset = AnsiblePlaybookRun.start_running(run, @now)

      assert errors_on(changeset) == %{}

      assert Changeset.apply_changes(changeset) ==
               %{run | state: :running, started_at: @now, updated_at: @now}
    end
  end

  describe "succeed/2" do
    test "moves a running run to the succeeded state with a zero exit code" do
      run = running_run()

      changeset = AnsiblePlaybookRun.succeed(run, @now)

      assert errors_on(changeset) == %{}

      assert Changeset.apply_changes(changeset) ==
               %{run | state: :succeeded, exit_code: 0, finished_at: @now, updated_at: @now}
    end

    test "rejects a finished date earlier than the start date" do
      run = ServersFactory.build(:ansible_playbook_run, state: :running, started_at: tomorrow())

      assert errors_on(AnsiblePlaybookRun.succeed(run, @now)) ==
               %{finished_at: ["must be after the start date"]}
    end

    # Regression: `validate_started_at_and_finished_at` used to compare the two
    # instants with `Date.compare/2`, so a `finished_at` earlier than
    # `started_at` on the same calendar day was wrongly accepted.
    test "rejects a finished date earlier than the start date on the same day" do
      run =
        ServersFactory.build(:ansible_playbook_run,
          state: :running,
          started_at: ~U[2024-03-15 10:30:05.000000Z]
        )

      assert errors_on(AnsiblePlaybookRun.succeed(run, @now)) ==
               %{finished_at: ["must be after the start date"]}
    end
  end

  describe "fail/3" do
    test "moves a running run to the failed state with the given exit code" do
      run = running_run()

      changeset = AnsiblePlaybookRun.fail(run, 42, @now)

      assert errors_on(changeset) == %{}

      assert Changeset.apply_changes(changeset) ==
               %{run | state: :failed, exit_code: 42, finished_at: @now, updated_at: @now}
    end

    test "moves a running run to the failed state with no exit code" do
      run = running_run()

      changeset = AnsiblePlaybookRun.fail(run, nil, @now)

      assert errors_on(changeset) == %{}

      assert Changeset.apply_changes(changeset) ==
               %{run | state: :failed, exit_code: nil, finished_at: @now, updated_at: @now}
    end
  end

  describe "interrupt/2" do
    test "moves a run to the interrupted state and stamps finished_at" do
      run = running_run()

      changeset = AnsiblePlaybookRun.interrupt(run, @now)

      assert errors_on(changeset) == %{}

      assert Changeset.apply_changes(changeset) ==
               %{run | state: :interrupted, finished_at: @now, updated_at: @now}
    end
  end

  describe "time_out/2" do
    test "moves a run to the timeout state and stamps finished_at" do
      run = running_run()

      changeset = AnsiblePlaybookRun.time_out(run, @now)

      assert errors_on(changeset) == %{}

      assert Changeset.apply_changes(changeset) ==
               %{run | state: :timeout, finished_at: @now, updated_at: @now}
    end
  end

  describe "touch_new_event/2" do
    test "increments the event count and records the event's timestamp" do
      run = persisted_run(number_of_events: 3, last_event_at: nil, updated_at: @before_now)
      event = ServersFactory.build(:ansible_playbook_event, run: run, run_id: run.id)

      previous_counts = count_rows(@affected_tables)

      {1, nil} = Repo.update_all(AnsiblePlaybookRun.touch_new_event(run, event), [])

      assert Repo.get!(AnsiblePlaybookRun, run.id) ==
               %{
                 run
                 | number_of_events: 4,
                   last_event_at: event.created_at,
                   updated_at: event.created_at
               }

      assert_no_row_count_diff(previous_counts)
    end
  end

  describe "update_stats/2" do
    test "copies the run statistics from the event data" do
      run =
        persisted_run(
          stats_changed: 0,
          stats_failures: 0,
          stats_ignored: 0,
          stats_ok: 0,
          stats_rescued: 0,
          stats_skipped: 0,
          stats_unreachable: 0
        )

      event =
        ServersFactory.build(:ansible_playbook_event,
          run: run,
          run_id: run.id,
          data: %{
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
        )

      previous_counts = count_rows(@affected_tables)

      {1, nil} = Repo.update_all(AnsiblePlaybookRun.update_stats(run, event), [])

      assert Repo.get!(AnsiblePlaybookRun, run.id) ==
               %{
                 run
                 | stats_changed: 1,
                   stats_failures: 2,
                   stats_ignored: 3,
                   stats_ok: 4,
                   stats_rescued: 5,
                   stats_skipped: 6,
                   stats_unreachable: 7
               }

      assert_no_row_count_diff(previous_counts)
    end

    test "clears every statistic when the event carries no stats" do
      run =
        persisted_run(
          stats_changed: 1,
          stats_failures: 2,
          stats_ignored: 3,
          stats_ok: 4,
          stats_rescued: 5,
          stats_skipped: 6,
          stats_unreachable: 7
        )

      event = ServersFactory.build(:ansible_playbook_event, run: run, run_id: run.id, data: %{})

      previous_counts = count_rows(@affected_tables)

      {1, nil} = Repo.update_all(AnsiblePlaybookRun.update_stats(run, event), [])

      assert Repo.get!(AnsiblePlaybookRun, run.id) ==
               %{
                 run
                 | stats_changed: 0,
                   stats_failures: 0,
                   stats_ignored: 0,
                   stats_ok: 0,
                   stats_rescued: 0,
                   stats_skipped: 0,
                   stats_unreachable: 0
               }

      assert_no_row_count_diff(previous_counts)
    end
  end

  describe "done?/1" do
    for state <- [:pending, :running] do
      test "is false for the #{state} state" do
        run = ServersFactory.build(:ansible_playbook_run, state: unquote(state))

        assert AnsiblePlaybookRun.done?(run) == false
      end
    end

    for state <- [:succeeded, :failed, :interrupted, :timeout] do
      test "is true for the #{state} state" do
        run = ServersFactory.build(:ansible_playbook_run, state: unquote(state))

        assert AnsiblePlaybookRun.done?(run) == true
      end
    end
  end

  describe "duration/1" do
    test "is nil when the run has not finished" do
      run = ServersFactory.build(:ansible_playbook_run, finished_at: nil)

      assert AnsiblePlaybookRun.duration(run) == nil
    end

    test "is the number of milliseconds between creation and completion" do
      run =
        ServersFactory.build(:ansible_playbook_run,
          created_at: ~U[2024-03-15 10:00:00.000000Z],
          finished_at: ~U[2024-03-15 10:00:05.250000Z]
        )

      assert AnsiblePlaybookRun.duration(run) == 5250
    end
  end

  describe "ssh_connection_description/1" do
    test "omits the port when it is the default SSH port" do
      run =
        ServersFactory.build(:ansible_playbook_run,
          user: "alice",
          host: %Postgrex.INET{address: {10, 0, 0, 42}, netmask: nil},
          port: 22
        )

      assert AnsiblePlaybookRun.ssh_connection_description(run) == "alice@10.0.0.42"
    end

    test "includes the port when it is not the default SSH port" do
      run =
        ServersFactory.build(:ansible_playbook_run,
          user: "alice",
          host: %Postgrex.INET{address: {10, 0, 0, 42}, netmask: nil},
          port: 2222
        )

      assert AnsiblePlaybookRun.ssh_connection_description(run) == "alice@10.0.0.42:2222"
    end
  end

  describe "display_variables/1" do
    test "sorts the variables by key and tags the well-known ones as visible" do
      run =
        ServersFactory.build(:ansible_playbook_run,
          vars: %{
            "server_id" => "the-server",
            "ansible_user" => "deploy",
            "app_user_name" => "alice",
            "ansible_connection" => "ssh"
          }
        )

      assert AnsiblePlaybookRun.display_variables(run) == [
               {:hidden, "ansible_connection", "ssh"},
               {:hidden, "ansible_user", "deploy"},
               {:visible, "app_user_name", "alice"},
               {:visible, "server_id", "the-server"}
             ]
    end
  end

  describe "stats/1" do
    test "returns the run statistics as a map" do
      run =
        ServersFactory.build(:ansible_playbook_run,
          stats_changed: 1,
          stats_failures: 2,
          stats_ignored: 3,
          stats_ok: 4,
          stats_rescued: 5,
          stats_skipped: 6,
          stats_unreachable: 7
        )

      assert AnsiblePlaybookRun.stats(run) == %{
               changed: 1,
               failures: 2,
               ignored: 3,
               ok: 4,
               rescued: 5,
               skipped: 6,
               unreachable: 7
             }
    end
  end

  defp new_pending(overrides) do
    {playbook, without_playbook} =
      Keyword.pop_lazy(overrides, :playbook, fn ->
        AnsiblePlaybook.new("playbooks/setup.yml", "playbook-digest")
      end)

    {server, without_server} =
      Keyword.pop_lazy(without_playbook, :server, fn ->
        ServersFactory.build(:server, ssh_port: 2222)
      end)

    {user, []} = Keyword.pop(without_server, :user, "deploy")

    AnsiblePlaybookRun.new_pending(
      playbook,
      server,
      user,
      %{"ansible_user" => "deploy"},
      "vars-digest",
      @now
    )
  end

  # The well-known pending run `new_pending/6` builds from the canonical inputs
  # used across this describe block; `overrides` pins only the fields a given
  # test varies. The generated `id` and the repository's `git_revision` are
  # bound from the actual result.
  defp expected_pending_run(applied, server, overrides) do
    Map.merge(
      %AnsiblePlaybookRun{
        id: applied.id,
        playbook: "setup",
        playbook_path: "playbooks/setup.yml",
        playbook_digest: "playbook-digest",
        git_revision: applied.git_revision,
        host: server.ip_address,
        port: 2222,
        user: "deploy",
        vars: %{"ansible_user" => "deploy"},
        vars_digest: "vars-digest",
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
      },
      overrides
    )
  end

  defp running_run,
    do: ServersFactory.build(:ansible_playbook_run, state: :running, started_at: @before_now)

  defp tomorrow, do: ~U[2024-03-16 10:30:00.000000Z]

  defp persisted_run(attrs) do
    {owner, group} = persisted_owner_and_group()
    server = ServersTestHelpers.insert_server(owner.id, group.id)

    inserted =
      ServersFactory.insert(
        :ansible_playbook_run,
        Keyword.merge([server_id: server.id, created_at: @before_now], attrs)
      )

    Repo.get!(AnsiblePlaybookRun, inserted.id)
  end

  defp persisted_owner_and_group do
    {auth, _user_account} = ServersTestHelpers.register_root(@past)
    class = CourseFactory.insert(:class, now: @past)
    {:ok, group} = ServerGroup.fetch_server_group(class.id)
    owner = ServerOwner.fetch_authenticated(auth)
    {owner, group}
  end
end
