defmodule ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueueTest do
  # `async: false`: the queue reads the database in `init/1` (it marks
  # incomplete playbook runs as timed out), which runs before
  # `start_supervised!/1` returns the pid — too early for a per-pid
  # `Sandbox.allow/3`. Shared-mode sandbox (which `DataCase` enables for
  # non-async cases) lets the supervised process use the test's connection. A
  # process that read the database lazily instead could stay `async: true` and
  # use `Sandbox.allow/3` after start.
  use ArchiDep.Support.DataCase, async: false

  alias ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueue
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Support.EventsFactory
  alias Ecto.UUID

  setup %{test: test} do
    # A pipeline is identified by a module (`Pipeline.t()`), and the producer
    # registers globally as `{:global, {AnsiblePipelineQueue, pipeline}}`. The
    # ExUnit context's `:test` key is a unique atom per test, so using it gives
    # each test its own instance — isolated from the application's live pipeline
    # and from the other tests — without creating atoms at runtime.
    pipeline = test
    start_supervised!({AnsiblePipelineQueue, pipeline})
    %{pipeline: pipeline}
  end

  defp server, do: %Server{id: UUID.generate()}

  defp pending_run(%Server{id: server_id}),
    do: %AnsiblePlaybookRun{id: UUID.generate(), server_id: server_id, state: :pending}

  # Pull `count` events from the producer through a real GenStage consumer. The
  # demand drives the producer to dispatch its queued tasks, so the returned
  # list is exactly what flowed down the pipeline. `last_activity` is stamped
  # from wall-clock in the live glue and pinned exhaustively in the pure state
  # tests, so it is deliberately not observed here.
  defp consume(pipeline, count),
    do:
      [{AnsiblePipelineQueue.name(pipeline), max_demand: count, min_demand: 0}]
      |> GenStage.stream()
      |> Enum.take(count)

  test "boots with an empty queue", %{pipeline: pipeline} do
    assert AnsiblePipelineQueue.health(pipeline) == %{
             pending: 0,
             demand: 0,
             last_activity: nil
           }
  end

  test "dispatches enqueued gather-facts and run-playbook tasks in FIFO order", %{
    pipeline: pipeline
  } do
    target = server()
    run = pending_run(target)
    cause = EventsFactory.build(:event_reference)

    assert AnsiblePipelineQueue.gather_facts(pipeline, target, "deploy") == :ok
    assert AnsiblePipelineQueue.run_playbook(pipeline, run, cause) == :ok

    assert consume(pipeline, 2) == [
             {:gather_facts, target.id, "deploy"},
             {:run_playbook, run.id, cause}
           ]
  end

  test "drops a server's pending tasks when it goes offline", %{pipeline: pipeline} do
    offline = server()
    other = server()

    :ok = AnsiblePipelineQueue.gather_facts(pipeline, offline, "deploy")
    :ok = AnsiblePipelineQueue.gather_facts(pipeline, other, "ops")
    :ok = AnsiblePipelineQueue.server_offline(pipeline, offline)

    # `server_offline/2` is a cast; a synchronous `health/1` call shares the
    # process mailbox and is handled after it, so the drop is already applied
    # before we consume — no sleep or polling. Only the surviving server's task
    # is dispatched.
    _synced = AnsiblePipelineQueue.health(pipeline)

    assert consume(pipeline, 1) == [{:gather_facts, other.id, "ops"}]
  end
end
