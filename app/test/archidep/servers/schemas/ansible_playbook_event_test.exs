defmodule ArchiDep.Servers.Schemas.AnsiblePlaybookEventTest do
  use ArchiDep.Support.DataCase, async: true

  alias ArchiDep.Servers.Schemas.AnsiblePlaybookEvent
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Support.CourseFactory
  alias ArchiDep.Support.ServersFactory
  alias ArchiDep.Support.ServersTestHelpers
  alias Ecto.Changeset

  # `new/3` stamps `created_at` (and the `occurred_at` fallback) from the `now` it
  # is given, so a fixed instant makes every resulting changeset deterministic.
  @now ~U[2024-03-15 09:00:00.000000Z]
  # A safely-past instant for the persisted owner/group/server graph the
  # `fetch_events_for_run/1` test runs against.
  @past ~U[2024-01-01 00:00:00.000000Z]

  describe "new/3" do
    test "extracts every field from a full event data map" do
      run = ServersFactory.build(:ansible_playbook_run)

      data = %{
        "_event" => "v2_runner_on_ok",
        "_timestamp" => "2024-03-15T10:30:00.000000Z",
        "hosts" => %{"archidep" => %{"action" => "command", "changed" => true}},
        "task" => %{
          "name" => "Install packages",
          "id" => "11111111-1111-1111-1111-111111111111",
          "start" => "2024-03-15T10:00:00.000000Z",
          "end" => "2024-03-15T10:05:00.000000Z"
        }
      }

      changeset = AnsiblePlaybookEvent.new(data, run, @now)

      assert errors_on(changeset) == %{}

      applied = Changeset.apply_changes(changeset)

      assert applied ==
               expected_event(applied, run, data, %{
                 name: "v2_runner_on_ok",
                 action: "command",
                 changed: true,
                 task_name: "Install packages",
                 task_id: "11111111-1111-1111-1111-111111111111",
                 task_started_at: ~U[2024-03-15 10:00:00.000000Z],
                 task_ended_at: ~U[2024-03-15 10:05:00.000000Z],
                 occurred_at: ~U[2024-03-15 10:30:00.000000Z]
               })
    end

    test "falls back to defaults for an empty data map" do
      run = ServersFactory.build(:ansible_playbook_run)

      changeset = AnsiblePlaybookEvent.new(%{}, run, @now)

      assert errors_on(changeset) == %{}

      applied = Changeset.apply_changes(changeset)

      assert applied == expected_event(applied, run, %{}, %{})
    end

    test "falls back to \"_\" for the name when _event is not a string" do
      run = ServersFactory.build(:ansible_playbook_run)
      data = %{"_event" => 123}

      changeset = AnsiblePlaybookEvent.new(data, run, @now)

      assert errors_on(changeset) == %{}

      applied = Changeset.apply_changes(changeset)

      assert applied == expected_event(applied, run, data, %{name: "_"})
    end

    test "falls back to nil for the action when it is not a string" do
      run = ServersFactory.build(:ansible_playbook_run)
      data = %{"hosts" => %{"archidep" => %{"action" => 42}}}

      changeset = AnsiblePlaybookEvent.new(data, run, @now)

      assert errors_on(changeset) == %{}

      applied = Changeset.apply_changes(changeset)

      assert applied == expected_event(applied, run, data, %{action: nil})
    end

    test "falls back to false for changed when it is not a boolean" do
      run = ServersFactory.build(:ansible_playbook_run)
      data = %{"hosts" => %{"archidep" => %{"changed" => "yes"}}}

      changeset = AnsiblePlaybookEvent.new(data, run, @now)

      assert errors_on(changeset) == %{}

      applied = Changeset.apply_changes(changeset)

      assert applied == expected_event(applied, run, data, %{changed: false})
    end

    test "extracts occurred_at from a valid UTC timestamp" do
      run = ServersFactory.build(:ansible_playbook_run)
      data = %{"_timestamp" => "2024-03-15T10:30:00.000000Z"}

      changeset = AnsiblePlaybookEvent.new(data, run, @now)

      assert errors_on(changeset) == %{}

      applied = Changeset.apply_changes(changeset)

      assert applied ==
               expected_event(applied, run, data, %{occurred_at: ~U[2024-03-15 10:30:00.000000Z]})
    end

    test "falls back to now when timestamp has a non-zero UTC offset" do
      run = ServersFactory.build(:ansible_playbook_run)
      data = %{"_timestamp" => "2024-03-15T10:30:00.000000+01:00"}

      changeset = AnsiblePlaybookEvent.new(data, run, @now)

      assert errors_on(changeset) == %{}

      applied = Changeset.apply_changes(changeset)

      assert applied == expected_event(applied, run, data, %{occurred_at: @now})
    end

    test "falls back to now when _timestamp is not a valid datetime" do
      run = ServersFactory.build(:ansible_playbook_run)
      data = %{"_timestamp" => "not-a-datetime"}

      changeset = AnsiblePlaybookEvent.new(data, run, @now)

      assert errors_on(changeset) == %{}

      applied = Changeset.apply_changes(changeset)

      assert applied == expected_event(applied, run, data, %{occurred_at: @now})
    end

    test "ignores task timestamps that are not valid datetimes" do
      run = ServersFactory.build(:ansible_playbook_run)
      data = %{"task" => %{"start" => "nope", "end" => 0}}

      changeset = AnsiblePlaybookEvent.new(data, run, @now)

      assert errors_on(changeset) == %{}

      applied = Changeset.apply_changes(changeset)

      assert applied ==
               expected_event(applied, run, data, %{task_started_at: nil, task_ended_at: nil})
    end

    test "trims the name and nils-out blank action and task fields" do
      run = ServersFactory.build(:ansible_playbook_run)

      data = %{
        "_event" => "  setup  ",
        "hosts" => %{"archidep" => %{"action" => "   "}},
        "task" => %{"name" => "   ", "id" => "   "}
      }

      changeset = AnsiblePlaybookEvent.new(data, run, @now)

      assert errors_on(changeset) == %{}

      applied = Changeset.apply_changes(changeset)

      assert applied ==
               expected_event(applied, run, data, %{
                 name: "setup",
                 action: nil,
                 task_name: nil,
                 task_id: nil
               })
    end

    test "truncates the name, action, task_name and task_id to 255 characters" do
      run = ServersFactory.build(:ansible_playbook_run)
      long = String.duplicate("a", 300)

      data = %{
        "_event" => long,
        "hosts" => %{"archidep" => %{"action" => long}},
        "task" => %{"name" => long, "id" => long}
      }

      changeset = AnsiblePlaybookEvent.new(data, run, @now)

      assert errors_on(changeset) == %{}

      applied = Changeset.apply_changes(changeset)
      truncated = String.duplicate("a", 255)

      assert applied ==
               expected_event(applied, run, data, %{
                 name: truncated,
                 action: truncated,
                 task_name: truncated,
                 task_id: truncated
               })
    end

    # The remaining `validate/1` rules cannot be driven through `new/3`: each
    # `validate_length(max: 255)` runs after the matching field has already been
    # truncated to 255 characters, and `run_id`, `data` and `occurred_at` always
    # receive a value (the run's id, the raw data map, and the `now` fallback).
    # Only `name` can be made blank — a whitespace-only `_event` trims to "".
    test "the name cannot be blank when event is whitespace" do
      run = ServersFactory.build(:ansible_playbook_run)

      assert errors_on(AnsiblePlaybookEvent.new(%{"_event" => "   "}, run, @now)) ==
               %{name: ["can't be blank"]}
    end
  end

  describe "fetch_events_for_run/1" do
    test "returns the run's events ordered by occurrence, most recent first" do
      {owner, group} = persisted_owner_and_group()
      server = ServersTestHelpers.insert_server(owner.id, group.id)

      run = ServersFactory.insert(:ansible_playbook_run, server_id: server.id, created_at: @past)

      other_run =
        ServersFactory.insert(:ansible_playbook_run, server_id: server.id, created_at: @past)

      oldest =
        ServersFactory.insert(:ansible_playbook_event,
          run: not_loaded(:run, AnsiblePlaybookEvent),
          run_id: run.id,
          occurred_at: ~U[2024-03-15 10:00:00.000000Z]
        )

      newest =
        ServersFactory.insert(:ansible_playbook_event,
          run: not_loaded(:run, AnsiblePlaybookEvent),
          run_id: run.id,
          occurred_at: ~U[2024-03-15 12:00:00.000000Z]
        )

      middle =
        ServersFactory.insert(:ansible_playbook_event,
          run: not_loaded(:run, AnsiblePlaybookEvent),
          run_id: run.id,
          occurred_at: ~U[2024-03-15 11:00:00.000000Z]
        )

      _other =
        ServersFactory.insert(:ansible_playbook_event,
          run: not_loaded(:run, AnsiblePlaybookEvent),
          run_id: other_run.id,
          occurred_at: ~U[2024-03-15 13:00:00.000000Z]
        )

      assert AnsiblePlaybookEvent.fetch_events_for_run(run.id) == [newest, middle, oldest]
    end
  end

  # The well-known empty-extraction event `new/3` builds when the data map
  # carries no values; `overrides` pins only the fields a given test varies. The
  # generated `id` is bound from the actual result and `data` echoes the raw map
  # passed in.
  defp expected_event(applied, run, data, overrides) do
    Map.merge(
      %AnsiblePlaybookEvent{
        id: applied.id,
        run: run,
        run_id: run.id,
        name: "_",
        action: nil,
        changed: false,
        data: data,
        task_name: nil,
        task_id: nil,
        task_started_at: nil,
        task_ended_at: nil,
        occurred_at: @now,
        created_at: @now
      },
      overrides
    )
  end

  defp persisted_owner_and_group do
    {auth, _user_account} = ServersTestHelpers.register_root(@past)
    class = CourseFactory.insert(:class, now: @past)
    {:ok, group} = ServerGroup.fetch_server_group(class.id)
    owner = ServerOwner.fetch_authenticated(auth)
    {owner, group}
  end
end
