defmodule ArchiDep.Servers.Ansible.RunnerCompatibilityTest do
  # Certifies that the real `ansible`/`ansible-playbook` the production
  # `ArchiDep.Servers.Ansible.Runner` shells out to still emits the output
  # shapes the app parses — a canary for Ansible / `ansible.posix` callback
  # drift that every mocked unit test misses. It pins the fact keys
  # `ServerProperties.update_from_ansible_facts/2` consumes and the JSONL event
  # and stats shapes `AnsiblePlaybookEvent`/`AnsiblePlaybookRun` consume. See
  # the "Testing external-tool compatibility" section in `docs/testing.md`.
  #
  # Whole-value note: a real tool's output carries values that are inherently
  # non-deterministic (the container host's CPU/memory, generated UUIDs, real
  # timestamps, the raw fact/event blobs). Where they occur, each is bound and
  # its shape validated first, then folded back into a single exact `==`
  # assertion that pins everything else literally. This bind-then-`==` structure
  # is a **one-time approved** exception to the whole-value rule, granted only
  # because these values cannot be known ahead of time; it is not license to
  # write partial assertions elsewhere without explicit approval.
  use ArchiDep.Support.DataCase, async: true

  import Hammox
  alias ArchiDep.Servers.Ansible.Runner
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookEvent
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias ArchiDep.Support.ServersFactory
  alias ArchiDep.Support.ServersTestHelpers
  alias ArchiDep.Support.UbuntuServerContainer

  @moduletag :external

  @now ~U[2024-01-01 00:00:00.000000Z]

  setup :verify_on_exit!

  setup_all do
    %{target: UbuntuServerContainer.start!()}
  end

  setup do
    # Point the compile-time `Cmd` façade mock at real ExCmd, so `Runner`'s
    # `Cmd.stream/2` runs the real ansible subprocess. `stub/3` maps the one
    # callback to `ExCmd.stream/2` directly, since `ExCmd` does not declare the
    # `Cmd` behaviour and so cannot be passed to `stub_with/2`. Driving `Runner`
    # directly from the test process keeps the stub in scope (no spawned task).
    stub(ArchiDep.Cmd.Mock, :stream, &ExCmd.stream/2)
    :ok
  end

  test "the real ansible gathers facts that map onto the fact keys the app reads",
       %{target: target} do
    assert {:ok, facts} = Runner.gather_facts(target.host, target.port, target.username)

    id = Ecto.UUID.generate()

    properties =
      id
      |> ServerProperties.blank()
      |> ServerProperties.update_from_ansible_facts(facts)
      |> Changeset.apply_changes()

    # The hardware/identity facts depend on the container's host (CPU arch, core
    # count, memory, the container's hostname and machine-id), so they cannot be
    # pinned literally: bind them and validate their shape.
    %ServerProperties{
      hostname: hostname,
      machine_id: machine_id,
      architecture: architecture,
      cpus: cpus,
      cores: cores,
      vcpus: vcpus,
      memory: memory,
      swap: swap
    } = properties

    assert is_binary(hostname)
    assert is_nil(machine_id) or is_binary(machine_id)
    assert is_binary(architecture)
    assert is_integer(cpus) and cpus > 0
    assert is_integer(cores) and cores > 0
    assert is_integer(vcpus) and vcpus > 0
    assert is_integer(memory) and memory > 0
    assert is_integer(swap) and swap >= 0

    # The container is a fixed Ubuntu-noble image, so the OS-identity facts are
    # pinned exactly; the validated hardware facts are folded back in so the
    # whole struct is asserted at once (nothing unexpected resolved or dropped).
    assert properties == %ServerProperties{
             id: id,
             hostname: hostname,
             machine_id: machine_id,
             architecture: architecture,
             cpus: cpus,
             cores: cores,
             vcpus: vcpus,
             memory: memory,
             swap: swap,
             system: "Linux",
             os_family: "Debian",
             distribution: "Ubuntu",
             distribution_release: "noble",
             distribution_version: "24.04"
           }
  end

  test "the real ansible-playbook streams JSONL events and stats the app decodes",
       %{target: target} do
    %{owner: owner, class: class} = ServersTestHelpers.register_group_member(@now)
    server = ServersTestHelpers.insert_server(owner.id, class.id, active: true, ssh_port: 2222)
    run = ServersFactory.insert(:ansible_playbook_run, server: server)

    playbook = Path.join(File.cwd!(), "test/priv/ansible/compat.yml")

    elements =
      playbook
      |> Runner.run_playbook(target.host, target.port, target.username, %{})
      |> Enum.to_list()

    assert List.last(elements) == {:exit, {:status, 0}}

    events =
      for {:event, data} <- elements,
          do: data |> AnsiblePlaybookEvent.new(run, @now) |> Changeset.apply_changes()

    task_event = Enum.find(events, &(&1.name == "v2_runner_on_ok"))

    # The generated id, the raw event map, the ansible-assigned task id and the
    # real task/occurrence timestamps cannot be pinned literally: bind them and
    # validate their shape. That the task timestamps are `DateTime`s certifies
    # the real per-task timing still decodes through `new/3`.
    assert %AnsiblePlaybookEvent{
             id: event_id,
             data: data,
             task_id: task_id,
             task_started_at: task_started_at,
             task_ended_at: task_ended_at,
             occurred_at: occurred_at
           } = task_event

    assert is_binary(event_id)
    assert is_map(data)
    assert is_binary(task_id)
    assert %DateTime{} = task_started_at
    assert %DateTime{} = task_ended_at
    assert %DateTime{} = occurred_at

    # The rest is deterministic for our one command; fold the validated values
    # back in and assert the whole decoded event at once.
    assert task_event == %AnsiblePlaybookEvent{
             id: event_id,
             run: run,
             run_id: run.id,
             name: "v2_runner_on_ok",
             action: "ansible.builtin.command",
             changed: false,
             data: data,
             task_name: "Run a trivial command on the managed node",
             task_id: task_id,
             task_started_at: task_started_at,
             task_ended_at: task_ended_at,
             occurred_at: occurred_at,
             created_at: @now
           }

    # Applying the stats event to the persisted run writes exactly the counts
    # our trivial playbook produces: one ok task, everything else zero. The
    # pre-update reload is the baseline (so the INET netmask round-trip does not
    # spuriously differ), and only the stats columns change.
    stats_event = Enum.find(events, &(&1.name == "v2_playbook_on_stats"))
    before_update = Repo.get!(AnsiblePlaybookRun, run.id)

    assert {1, nil} = Repo.update_all(AnsiblePlaybookRun.update_stats(run, stats_event), [])

    assert Repo.get!(AnsiblePlaybookRun, run.id) ==
             %{
               before_update
               | stats_changed: 0,
                 stats_failures: 0,
                 stats_ignored: 0,
                 stats_ok: 1,
                 stats_rescued: 0,
                 stats_skipped: 0,
                 stats_unreachable: 0
             }
  end
end
