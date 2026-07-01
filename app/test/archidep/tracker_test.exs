defmodule ArchiDep.TrackerTest do
  use ExUnit.Case, async: true

  alias Phoenix.PubSub

  @pubsub ArchiDep.PubSub

  setup do
    # A unique topic per test isolates the broadcasts (`tracker:<topic>` is a
    # global, unscoped topic), keeping the test `async: true`.
    topic = "test-#{System.unique_integer([:positive])}"
    :ok = PubSub.subscribe(@pubsub, "tracker:#{topic}")
    %{topic: topic}
  end

  test "broadcasts a join for each joined key", %{topic: topic} do
    meta = %{state: :up}

    assert ArchiDep.Tracker.handle_diff(%{topic => {[{"server-1", meta}], []}}, :tracker_state) ==
             {:ok, :tracker_state}

    assert_receive {:join, "server-1", ^meta}
  end

  test "broadcasts a leave for each left key", %{topic: topic} do
    meta = %{state: :down}

    assert ArchiDep.Tracker.handle_diff(%{topic => {[], [{"server-1", meta}]}}, :tracker_state) ==
             {:ok, :tracker_state}

    assert_receive {:leave, "server-1", ^meta}
  end

  test "merges a simultaneous leave and join of the same key into an update", %{topic: topic} do
    left_meta = %{state: :old}
    joined_meta = %{state: :new}

    assert ArchiDep.Tracker.handle_diff(
             %{topic => {[{"server-1", joined_meta}], [{"server-1", left_meta}]}},
             :tracker_state
           ) == {:ok, :tracker_state}

    assert_receive {:update, "server-1", ^joined_meta}
    refute_received {:join, "server-1", _meta}
    refute_received {:leave, "server-1", _meta}
  end
end
