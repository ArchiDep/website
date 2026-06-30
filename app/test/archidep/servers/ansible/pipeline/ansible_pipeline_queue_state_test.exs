defmodule ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueueStateTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Servers.Ansible.Pipeline.AnsiblePipelineQueue.State
  alias ArchiDep.Support.EventsFactory
  alias Ecto.UUID

  # The queue's logic is a pure state machine; the surrounding GenStage is thin
  # glue. We unit-test the state machine here by passing `%State{}` structs
  # through its functions and asserting the whole returned struct by equality,
  # which keeps these tests fast and free of process/database machinery (the
  # process wiring is covered in `ansible_pipeline_queue_test.exs`).
  #
  # `pending_tasks` embeds an Erlang `:queue`, whose internal representation is
  # not canonical (two queues with the same elements can compare unequal with
  # `==`). `normalize/1` rewrites it to the FIFO list of its elements so the
  # whole-struct equality is meaningful; expected structs are built in that same
  # normalized form. This is specific to this state, so it stays here rather
  # than in the testing guidelines.

  @pipeline :test_pipeline
  @now ~U[2024-03-15 10:30:00.000000Z]
  @later ~U[2024-03-15 10:35:00.000000Z]

  defp normalize(%State{pending_tasks: {count, queue}} = state),
    do: %State{state | pending_tasks: {count, :queue.to_list(queue)}}

  defp empty_state, do: State.init(@pipeline)

  defp gather_facts_task(server_id, username),
    do: %{type: :gather_facts, server_id: server_id, username: username}

  defp run_playbook_task(run_id, server_id, cause),
    do: %{type: :run_playbook, run_id: run_id, server_id: server_id, cause: cause}

  test "init/1 builds an empty queue for the pipeline" do
    assert normalize(State.init(@pipeline)) == %State{
             pipeline: @pipeline,
             stored_demand: 0,
             pending_tasks: {0, []},
             last_activity: nil
           }
  end

  test "store_demand/2 accumulates demand" do
    state = State.store_demand(empty_state(), 5)

    assert normalize(State.store_demand(state, 2)) == %State{
             pipeline: @pipeline,
             stored_demand: 7,
             pending_tasks: {0, []},
             last_activity: nil
           }
  end

  describe "gather_facts/4" do
    test "enqueues a gather-facts task and starts the activity clock when idle" do
      server_id = UUID.generate()

      assert normalize(State.gather_facts(empty_state(), server_id, "deploy", @now)) == %State{
               pipeline: @pipeline,
               stored_demand: 0,
               pending_tasks: {1, [gather_facts_task(server_id, "deploy")]},
               last_activity: @now
             }
    end

    test "keeps the existing activity clock when tasks are already pending" do
      first_server = UUID.generate()
      second_server = UUID.generate()

      state = State.gather_facts(empty_state(), first_server, "deploy", @now)

      assert normalize(State.gather_facts(state, second_server, "ops", @later)) == %State{
               pipeline: @pipeline,
               stored_demand: 0,
               pending_tasks: {
                 2,
                 [
                   gather_facts_task(first_server, "deploy"),
                   gather_facts_task(second_server, "ops")
                 ]
               },
               last_activity: @now
             }
    end
  end

  describe "run_playbook/5" do
    test "enqueues a run-playbook task and starts the activity clock when idle" do
      run_id = UUID.generate()
      server_id = UUID.generate()
      cause = EventsFactory.build(:event_reference)

      assert normalize(State.run_playbook(empty_state(), run_id, server_id, cause, @now)) ==
               %State{
                 pipeline: @pipeline,
                 stored_demand: 0,
                 pending_tasks: {1, [run_playbook_task(run_id, server_id, cause)]},
                 last_activity: @now
               }
    end
  end

  describe "server_offline/2" do
    test "drops only the offline server's pending tasks and keeps the order of the rest" do
      offline_server = UUID.generate()
      first_server = UUID.generate()
      second_server = UUID.generate()
      run_id = UUID.generate()
      cause = EventsFactory.build(:event_reference)

      # Interleave the offline server's tasks between two survivors so the
      # assertion shows the survivors are kept in their original FIFO order.
      state =
        empty_state()
        |> State.gather_facts(first_server, "deploy", @now)
        |> State.gather_facts(offline_server, "doomed", @now)
        |> State.run_playbook(run_id, second_server, cause, @now)
        |> State.gather_facts(offline_server, "doomed-too", @now)

      assert normalize(State.server_offline(state, offline_server)) == %State{
               pipeline: @pipeline,
               stored_demand: 0,
               pending_tasks: {
                 2,
                 [
                   gather_facts_task(first_server, "deploy"),
                   run_playbook_task(run_id, second_server, cause)
                 ]
               },
               last_activity: @now
             }
    end

    test "clears the activity clock when the last pending task is dropped" do
      server_id = UUID.generate()

      state = State.gather_facts(empty_state(), server_id, "deploy", @now)

      assert normalize(State.server_offline(state, server_id)) == %State{
               pipeline: @pipeline,
               stored_demand: 0,
               pending_tasks: {0, []},
               last_activity: nil
             }
    end

    test "leaves an empty queue untouched" do
      assert normalize(State.server_offline(empty_state(), UUID.generate())) ==
               %State{
                 pipeline: @pipeline,
                 stored_demand: 0,
                 pending_tasks: {0, []},
                 last_activity: nil
               }
    end
  end

  describe "consume_events/2" do
    test "returns no events and leaves the state untouched when there is no demand" do
      server_id = UUID.generate()
      state = State.gather_facts(empty_state(), server_id, "deploy", @now)

      assert {events, new_state} = State.consume_events(state, @later)
      assert events == []

      assert normalize(new_state) == %State{
               pipeline: @pipeline,
               stored_demand: 0,
               pending_tasks: {1, [gather_facts_task(server_id, "deploy")]},
               last_activity: @now
             }
    end

    test "clears the activity clock when demand outlasts the pending tasks" do
      state = State.store_demand(empty_state(), 3)

      assert {events, new_state} = State.consume_events(state, @later)
      assert events == []

      assert normalize(new_state) == %State{
               pipeline: @pipeline,
               stored_demand: 3,
               pending_tasks: {0, []},
               last_activity: nil
             }
    end

    test "emits tasks in FIFO order up to the available demand, holding back the rest" do
      first_server = UUID.generate()
      run_id = UUID.generate()
      second_server = UUID.generate()
      third_server = UUID.generate()
      cause = EventsFactory.build(:event_reference)

      state =
        empty_state()
        |> State.gather_facts(first_server, "deploy", @now)
        |> State.run_playbook(run_id, second_server, cause, @now)
        |> State.gather_facts(third_server, "ops", @now)
        |> State.store_demand(2)

      assert {events, new_state} = State.consume_events(state, @later)

      assert events == [
               {:gather_facts, first_server, "deploy"},
               {:run_playbook, run_id, cause}
             ]

      assert normalize(new_state) == %State{
               pipeline: @pipeline,
               stored_demand: 0,
               pending_tasks: {1, [gather_facts_task(third_server, "ops")]},
               last_activity: @later
             }
    end
  end

  describe "health/1" do
    test "reports the pending count, outstanding demand and last activity" do
      server_id = UUID.generate()

      state =
        empty_state()
        |> State.store_demand(4)
        |> State.gather_facts(server_id, "deploy", @now)

      assert State.health(state) == %{pending: 1, demand: 4, last_activity: @now}
    end
  end
end
