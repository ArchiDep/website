defmodule ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueueTest.NoOpStore do
  @moduledoc false
  @behaviour ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueueStoreBehaviour

  @impl ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueueStoreBehaviour
  def mark_incomplete_runs_as_timed_out, do: :ok
end

defmodule ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueueTest do
  # `async: true`: the queue's only database work — marking incomplete runs as
  # timed out on boot — is behind the injected store, replaced here by a no-op
  # fake, so `init/1` touches neither the database nor any owner-scoped mock.
  # The real store's behaviour is covered by
  # `ansible_pipeline_queue_store_test.exs`.
  use ArchiDep.Support.DataCase, async: true

  import ArchiDep.Support.ProcessTestHelpers, only: [wait_for!: 2]
  alias ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueue
  alias ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueueTest.NoOpStore
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Support.EventsFactory
  alias Ecto.UUID

  @tracker ArchiDep.Tracker

  setup %{test: test} do
    # A pipeline is identified by a module (`Pipeline.t()`), and the producer
    # registers globally as `{:global, {AnsiblePipelineQueue, pipeline}}`. The
    # ExUnit context's `:test` key is a unique atom per test, so using it gives
    # each test its own instance — isolated from the application's live pipeline
    # and from the other tests — without creating atoms at runtime.
    pipeline = test

    start_supervised!(%{
      id: AnsiblePipelineQueue,
      start: {AnsiblePipelineQueue, :start_link, [pipeline, [store: NoOpStore]]}
    })

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

  test "publishes its demand and pending counts to the tracker", %{pipeline: pipeline} do
    assert_tracked_counts!(pipeline, %{demand: 0, pending: 0})

    # No consumer is subscribed, so the task stays pending and the tracked
    # counts grow by one.
    :ok = AnsiblePipelineQueue.gather_facts(pipeline, server(), "deploy")

    assert_tracked_counts!(pipeline, %{demand: 0, pending: 1})
  end

  # `Phoenix.Tracker` is eventually consistent, so poll until the queue's
  # presence reflects the expected counts. The `:phx_ref` bookkeeping the tracker
  # adds is its own, not data the queue publishes, so only the published counts
  # are asserted.
  defp assert_tracked_counts!(pipeline, counts),
    do:
      wait_for!(
        fn -> tracked_counts(pipeline) == counts end,
        "queue never published #{inspect(counts)} to the tracker"
      )

  defp tracked_counts(pipeline) do
    @tracker
    |> Phoenix.Tracker.list("ansible-queue")
    |> Enum.find_value(fn {key, meta} ->
      if key == "queue:#{pipeline}", do: Map.take(meta, [:demand, :pending])
    end)
  end
end
