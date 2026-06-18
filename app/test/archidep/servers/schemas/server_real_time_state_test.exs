defmodule ArchiDep.Servers.Schemas.ServerRealTimeStateTest do
  use ExUnit.Case, async: true

  import ArchiDep.Servers.ServerTracking.ServerConnectionState
  import ArchiDep.Support.ServerManagerStateTestUtils
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDep.Support.ServersFactory

  # The connection states for which a server is considered idle as long as it has
  # no current job.
  @idle_when_jobless [
    {"not connected", not_connected_state()},
    {"connection pending", connection_pending_state()},
    {"connected", connected_state()},
    {"retry connecting", retry_connecting_state()},
    {"connection failed", connection_failed_state()},
    {"disconnected", disconnected_state()}
  ]

  # The connection states that have no jobless clause and are therefore always
  # considered busy, even with no current job.
  @always_busy [
    {"connecting", connecting_state()},
    {"reconnecting", reconnecting_state()}
  ]

  describe "busy?/1" do
    test "no state is not busy" do
      assert ServerRealTimeState.busy?(nil) == false
    end

    for {label, connection_state} <- @idle_when_jobless do
      test "a #{label} server with no current job is not busy" do
        server = ServersFactory.build(:server)

        state =
          real_time_state(server,
            connection_state: unquote(Macro.escape(connection_state)),
            current_job: nil
          )

        assert ServerRealTimeState.busy?(state) == false
      end

      test "a #{label} server with a current job is busy" do
        server = ServersFactory.build(:server)

        state =
          real_time_state(server,
            connection_state: unquote(Macro.escape(connection_state)),
            current_job: :gathering_facts
          )

        assert ServerRealTimeState.busy?(state) == true
      end
    end

    for {label, connection_state} <- @always_busy do
      test "a #{label} server is busy even with no current job" do
        server = ServersFactory.build(:server)

        state =
          real_time_state(server,
            connection_state: unquote(Macro.escape(connection_state)),
            current_job: nil
          )

        assert ServerRealTimeState.busy?(state) == true
      end
    end
  end

  describe "problem?/2" do
    test "no state has no problem" do
      assert ServerRealTimeState.problem?(nil, [:server_connection_refused]) == false
    end

    test "a server with no problem does not have a problem" do
      server = ServersFactory.build(:server)
      state = real_time_state(server, problems: [])

      assert ServerRealTimeState.problem?(state, [:server_connection_refused]) == false
    end

    test "a server with a problem of one of the given types has a problem" do
      server = ServersFactory.build(:server)

      state =
        real_time_state(server, problems: [ServersFactory.server_connection_refused_problem()])

      assert ServerRealTimeState.problem?(state, [:server_connection_refused]) == true
    end

    test "a server with a problem of none of the given types does not have a problem" do
      server = ServersFactory.build(:server)

      state =
        real_time_state(server, problems: [ServersFactory.server_connection_refused_problem()])

      assert ServerRealTimeState.problem?(state, [:server_authentication_failed]) == false
    end

    test "a server with several problems, one of a given type, has a problem" do
      server = ServersFactory.build(:server)

      state =
        real_time_state(server,
          problems: [
            ServersFactory.server_connection_refused_problem(),
            ServersFactory.server_connection_timed_out_problem()
          ]
        )

      assert ServerRealTimeState.problem?(
               state,
               [:server_authentication_failed, :server_connection_timed_out]
             ) == true
    end
  end
end
