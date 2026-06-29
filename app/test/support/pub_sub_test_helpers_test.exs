defmodule ArchiDep.Support.PubSubTestHelpersTest do
  use ExUnit.Case, async: true

  import ArchiDep.Support.PubSubTestHelpers

  @pubsub ArchiDep.PubSub

  describe "collect_broadcasts/1 and received_broadcasts/1" do
    test "returns an empty list when the topic received nothing" do
      collector = collect_broadcasts(fn -> subscribe(unique_topic()) end)
      assert received_broadcasts(collector) == []
    end

    test "returns the messages a topic received, in order" do
      topic = unique_topic()
      collector = collect_broadcasts(fn -> subscribe(topic) end)

      broadcast(topic, {:event, 1})
      broadcast(topic, {:event, 2})
      broadcast(topic, {:event, 3})

      assert received_broadcasts(collector) == [{:event, 1}, {:event, 2}, {:event, 3}]
    end

    test "attributes messages to the topic that delivered them" do
      topic_a = unique_topic()
      topic_b = unique_topic()
      collector_a = collect_broadcasts(fn -> subscribe(topic_a) end)
      collector_b = collect_broadcasts(fn -> subscribe(topic_b) end)

      broadcast(topic_a, {:only, :a})
      broadcast(topic_b, {:only, :b})
      broadcast(topic_b, {:also, :b})

      assert received_broadcasts(collector_a) == [{:only, :a}]
      assert received_broadcasts(collector_b) == [{:only, :b}, {:also, :b}]
    end

    test "can be drained repeatedly, accumulating later broadcasts" do
      topic = unique_topic()
      collector = collect_broadcasts(fn -> subscribe(topic) end)

      broadcast(topic, {:event, 1})
      assert received_broadcasts(collector) == [{:event, 1}]

      broadcast(topic, {:event, 2})
      assert received_broadcasts(collector) == [{:event, 1}, {:event, 2}]
    end
  end

  defp unique_topic, do: "pub-sub-test-helpers:#{System.unique_integer([:positive])}"
  defp subscribe(topic), do: Phoenix.PubSub.subscribe(@pubsub, topic)
  defp broadcast(topic, message), do: Phoenix.PubSub.broadcast(@pubsub, topic, message)
end
