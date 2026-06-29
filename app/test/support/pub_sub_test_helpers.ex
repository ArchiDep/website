defmodule ArchiDep.Support.PubSubTestHelpers do
  @moduledoc """
  Helpers for asserting Phoenix PubSub broadcasts one topic at a time.

  A single use case often broadcasts the *same* message to several topics — a
  global topic, a per-group topic, a per-owner topic. Subscribing the test
  process to all of them funnels every message into one mailbox, where they can
  no longer be attributed to the topic that delivered them: a double broadcast
  on one topic with none on another is indistinguishable from one broadcast
  each.

  `collect_broadcasts/1` instead subscribes each topic in its own collector
  process — mirroring production, where every consumer (a LiveView, a channel)
  subscribes to exactly one of these topics. `received_broadcasts/1` then
  returns the exact list of messages that reached that one topic, so each topic
  is asserted on its own by whole-list equality (see `docs/testing.md`).

  Delivery to local subscribers is synchronous: by the time the broadcasting
  function returns, the message is already in each collector's mailbox. So
  `received_broadcasts/1` is a plain synchronous round-trip — it needs no
  timeout and never races the broadcast.
  """

  import ExUnit.Assertions

  # Private control message used to drain a collector. Tagged so it can never
  # collide with an actual broadcast payload.
  @drain :"$archidep_collect_drain"

  @doc """
  Subscribes to a single topic in a dedicated collector process and returns its
  pid, to be passed to `received_broadcasts/1`.

  `subscribe_fun` is the real subscribe call for the topic, run inside the
  collector so that it — and not the test process — becomes the subscriber. The
  collector is spawned as a `Task`, so it inherits the test's `$callers` chain
  and resolves the per-test topic scope and clock exactly as a LiveView would.

  Returns only once the subscription is registered, so a broadcast that happens
  after this call is guaranteed to be observed.

      owner = collect_broadcasts(fn -> PubSub.subscribe_server_owner_servers(owner.id) end)
      assert {:ok, server} = create_server.(auth, group.id, data)
      assert received_broadcasts(owner) == [{:server_created, server}]
  """
  @spec collect_broadcasts((-> :ok)) :: pid()
  def collect_broadcasts(subscribe_fun) when is_function(subscribe_fun, 0) do
    test = self()
    ack = make_ref()

    {:ok, collector} =
      Task.start_link(fn ->
        :ok = subscribe_fun.()
        send(test, {ack, :subscribed})
        collect_loop([])
      end)

    receive do
      {^ack, :subscribed} -> collector
    after
      1_000 -> flunk("PubSub collector did not subscribe within 1000ms")
    end
  end

  @doc """
  Returns the exact list of messages the collector has received so far, in the
  order they arrived.

  This is a synchronous round-trip behind any already-delivered broadcasts, so
  the returned list is complete: assert it by whole-list equality.
  """
  @spec received_broadcasts(pid()) :: [term()]
  def received_broadcasts(collector) when is_pid(collector) do
    ref = make_ref()
    send(collector, {@drain, self(), ref})

    receive do
      {^ref, :messages, messages} -> messages
    after
      1_000 -> flunk("PubSub collector did not respond within 1000ms")
    end
  end

  defp collect_loop(received) do
    receive do
      {@drain, from, ref} ->
        send(from, {ref, :messages, Enum.reverse(received)})
        collect_loop(received)

      message ->
        collect_loop([message | received])
    end
  end
end
