defmodule ArchiDep.Servers.ServerTracking.ServerTrackerTest do
  use ExUnit.Case, async: true

  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  import ArchiDep.Support.ProcessTestHelpers, only: [wait_for!: 2]
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDep.Servers.ServerTracking.ServerTracker
  alias ArchiDep.Support.Factory
  alias Ecto.UUID
  alias Phoenix.Tracker

  # The presence tracker is a shared global process, but every server is keyed
  # by a unique id, so tests never observe each other's entries — hence `async:
  # true`.
  @tracker ArchiDep.Tracker

  setup do
    server = %Server{id: UUID.generate()}

    # `start_link/1` captures its caller as the process to forward updates to,
    # so the tracker is started in (and forwards to) the test process; it is
    # linked here, so it is stopped explicitly rather than leaked.
    {:ok, tracker} = ServerTracker.start_link([server])
    on_exit(fn -> if Process.alive?(tracker), do: GenServer.stop(tracker) end)

    %{server: server, tracker: tracker}
  end

  describe "track/2" do
    test "returns the absent state of a server that is not currently tracked", %{
      server: server,
      tracker: tracker
    } do
      assert ServerTracker.track(tracker, server) == {:server_state, server.id, nil}
    end

    test "returns the current state of a server that is tracked", %{
      server: server,
      tracker: tracker
    } do
      state = server_state(1)
      track_in_tracker(server.id, state)
      await_tracked(server.id, state)

      assert ServerTracker.track(tracker, server) == {:server_state, server.id, state}
    end
  end

  test "untrack/2 returns the absent state of a server", %{server: server, tracker: tracker} do
    assert ServerTracker.untrack(tracker, server) == {:server_state, server.id, nil}
  end

  describe "forwarding presence changes to its caller" do
    test "forwards a more recent state", %{server: server, tracker: tracker} do
      server_id = server.id
      ServerTracker.track(tracker, server)

      state = server_state(1)
      send(tracker, {:join, server_id, %{state: state}})

      assert_receive {:server_state, ^server_id, ^state}
    end

    test "does not forward a less recent state", %{server: server, tracker: tracker} do
      server_id = server.id
      ServerTracker.track(tracker, server)

      newer = server_state(5)
      send(tracker, {:update, server_id, %{state: newer}})
      assert_receive {:server_state, ^server_id, ^newer}

      older = server_state(3)
      send(tracker, {:update, server_id, %{state: older}})
      _flushed = :sys.get_state(tracker)

      refute_received {:server_state, ^server_id, ^older}
    end

    test "forwards a leave as an absent state", %{server: server, tracker: tracker} do
      server_id = server.id
      ServerTracker.track(tracker, server)

      state = server_state(1)
      send(tracker, {:update, server_id, %{state: state}})
      assert_receive {:server_state, ^server_id, ^state}

      send(tracker, {:leave, server_id, %{state: state}})

      assert_receive {:server_state, ^server_id, nil}
    end

    test "ignores presence changes for a server it is not tracking", %{tracker: tracker} do
      other_id = UUID.generate()

      send(tracker, {:join, other_id, %{state: server_state(1)}})
      _flushed = :sys.get_state(tracker)

      refute_received {:server_state, _server_id, _state}
    end
  end

  describe "reading from the presence tracker" do
    test "returns the current state of tracked servers", %{server: server} do
      state = server_state(1)
      track_in_tracker(server.id, state)
      await_tracked(server.id, state)

      assert ServerTracker.get_current_server_state(server.id) == state
      assert ServerTracker.server_state_map([server]) == %{server.id => state}
    end

    test "forwards a real presence change from the tracker to its caller", %{
      server: server,
      tracker: tracker
    } do
      server_id = server.id
      ServerTracker.track(tracker, server)

      state = server_state(1)
      track_in_tracker(server_id, state)

      assert_receive {:server_state, ^server_id, ^state}, 1_000
    end
  end

  describe "self-managing owner scope" do
    test "tracks every one of the owner's servers under the :all scope" do
      {:ok, tracker} = ServerTracker.start_link(Factory.build(:authentication), [], :all)
      on_exit(fn -> if Process.alive?(tracker), do: GenServer.stop(tracker) end)

      created_id = UUID.generate()
      send(tracker, {:server_created, %{id: created_id, active: false}, :reference})

      assert_receive {:server_state, ^created_id, nil}
    end

    test "stops tracking a deleted server under the :all scope" do
      {:ok, tracker} = ServerTracker.start_link(Factory.build(:authentication), [], :all)
      on_exit(fn -> if Process.alive?(tracker), do: GenServer.stop(tracker) end)

      server_id = UUID.generate()
      send(tracker, {:server_created, %{id: server_id, active: true}, :reference})
      assert_receive {:server_state, ^server_id, nil}

      # Now that it is tracked, a presence change is forwarded.
      state = server_state(1)
      send(tracker, {:join, server_id, %{state: state}})
      assert_receive {:server_state, ^server_id, ^state}

      send(tracker, {:server_deleted, %{id: server_id}, :reference})
      assert_receive {:server_state, ^server_id, nil}

      # Now that it is untracked, a presence change is no longer forwarded.
      send(tracker, {:join, server_id, %{state: server_state(2)}})
      _flushed = :sys.get_state(tracker)

      refute_received {:server_state, ^server_id, _state}
    end

    test "tracks a created active server but ignores an inactive one under the :active scope" do
      {:ok, tracker} = ServerTracker.start_link(Factory.build(:authentication), [], :active)
      on_exit(fn -> if Process.alive?(tracker), do: GenServer.stop(tracker) end)

      active_id = UUID.generate()
      send(tracker, {:server_created, %{id: active_id, active: true}, :reference})
      assert_receive {:server_state, ^active_id, nil}

      inactive_id = UUID.generate()
      send(tracker, {:server_created, %{id: inactive_id, active: false}, :reference})
      _flushed = :sys.get_state(tracker)

      refute_received {:server_state, ^inactive_id, _state}
    end

    test "starts and stops tracking as a server flips active under the :active scope" do
      {:ok, tracker} = ServerTracker.start_link(Factory.build(:authentication), [], :active)
      on_exit(fn -> if Process.alive?(tracker), do: GenServer.stop(tracker) end)

      server_id = UUID.generate()

      send(tracker, {:server_updated, %{id: server_id, active: true}, :reference})
      assert_receive {:server_state, ^server_id, nil}

      # Now that it is tracked, a presence change is forwarded.
      state = server_state(1)
      send(tracker, {:join, server_id, %{state: state}})
      assert_receive {:server_state, ^server_id, ^state}

      send(tracker, {:server_updated, %{id: server_id, active: false}, :reference})
      assert_receive {:server_state, ^server_id, nil}

      # Now that it is untracked, a presence change is no longer forwarded.
      send(tracker, {:join, server_id, %{state: server_state(2)}})
      _flushed = :sys.get_state(tracker)

      refute_received {:server_state, ^server_id, _state}
    end
  end

  defp server_state(version),
    do: %ServerRealTimeState{
      connection_state: not_connected_state(),
      name: "server",
      conn_params: {{1, 2, 3, 4}, 22, "root"},
      username: "root",
      app_username: "app",
      version: version
    }

  defp track_in_tracker(server_id, state),
    do: {:ok, _ref} = Tracker.track(@tracker, self(), "servers", server_id, %{state: state})

  # `Phoenix.Tracker` is eventually consistent, so poll until the presence is
  # visible before asserting the read-back.
  defp await_tracked(server_id, state),
    do:
      wait_for!(
        fn -> ServerTracker.get_current_server_state(server_id) == state end,
        "server #{server_id} never appeared in the tracker"
      )
end
