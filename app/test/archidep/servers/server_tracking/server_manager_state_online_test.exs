defmodule ArchiDep.Servers.ServerTracking.ServerManagerStateOnlineTest do
  use ArchiDep.Support.DataCase, async: true

  import Hammox
  alias ArchiDep.Servers.ServerTracking.ServerManagerBehaviour
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Support.ServersFactory

  setup :verify_on_exit!

  setup_all do
    %{
      online?: protect({ServerManagerState, :online?, 1}, ServerManagerBehaviour)
    }
  end

  test "check whether a server is online", %{online?: online?} do
    build_state = fn connection_state ->
      ServersFactory.build(:server_manager_state, connection_state: connection_state)
    end

    state = build_state.(ServersFactory.random_connected_state())
    assert online?.(state) == true

    for state <-
          [
            ServersFactory.random_not_connected_state(),
            ServersFactory.random_connecting_state(),
            ServersFactory.random_retry_connecting_state(),
            ServersFactory.random_reconnecting_state(),
            ServersFactory.random_connection_failed_state(),
            ServersFactory.random_disconnected_state()
          ] do
      assert online?.(build_state.(state)) == false
    end
  end
end
