defmodule ArchiDep.Servers.ServerTracking.ServerConnectionStateTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Servers.ServerTracking.ServerConnectionState
  alias ArchiDep.Support.ServersFactory

  # Every predicate is asserted against every state variant at once, as a whole
  # projection of all predicates plus `connection_pid/1`, so that a variant
  # leaking `true` through the wrong predicate fails the equality.
  defp classify(state),
    do: %{
      connecting?: ServerConnectionState.connecting?(state),
      retry_connecting?: ServerConnectionState.retry_connecting?(state),
      connected?: ServerConnectionState.connected?(state),
      not_connected?: ServerConnectionState.not_connected?(state),
      connection_failed?: ServerConnectionState.connection_failed?(state),
      connection_pid: ServerConnectionState.connection_pid(state)
    }

  test "not-connected state" do
    state = ServersFactory.random_not_connected_state(%{connection_pid: self()})

    assert classify(state) == %{
             connecting?: false,
             retry_connecting?: false,
             connected?: false,
             not_connected?: true,
             connection_failed?: false,
             connection_pid: self()
           }
  end

  test "connection-pending state" do
    state = ServersFactory.random_connection_pending_state()

    assert classify(state) == %{
             connecting?: false,
             retry_connecting?: false,
             connected?: false,
             not_connected?: false,
             connection_failed?: false,
             connection_pid: self()
           }
  end

  test "connecting state" do
    state = ServersFactory.random_connecting_state()

    assert classify(state) == %{
             connecting?: true,
             retry_connecting?: false,
             connected?: false,
             not_connected?: false,
             connection_failed?: false,
             connection_pid: self()
           }
  end

  test "retry-connecting state" do
    state = ServersFactory.random_retry_connecting_state()

    assert classify(state) == %{
             connecting?: false,
             retry_connecting?: true,
             connected?: false,
             not_connected?: false,
             connection_failed?: false,
             connection_pid: self()
           }
  end

  test "connected state" do
    state = ServersFactory.random_connected_state()

    assert classify(state) == %{
             connecting?: false,
             retry_connecting?: false,
             connected?: true,
             not_connected?: false,
             connection_failed?: false,
             connection_pid: self()
           }
  end

  test "reconnecting state" do
    state = ServersFactory.random_reconnecting_state()

    assert classify(state) == %{
             connecting?: false,
             retry_connecting?: false,
             connected?: false,
             not_connected?: false,
             connection_failed?: false,
             connection_pid: self()
           }
  end

  test "connection-failed state" do
    state = ServersFactory.random_connection_failed_state()

    assert classify(state) == %{
             connecting?: false,
             retry_connecting?: false,
             connected?: false,
             not_connected?: false,
             connection_failed?: true,
             connection_pid: self()
           }
  end

  test "disconnected state" do
    state = ServersFactory.random_disconnected_state()

    assert classify(state) == %{
             connecting?: false,
             retry_connecting?: false,
             connected?: false,
             not_connected?: false,
             connection_failed?: false,
             connection_pid: nil
           }
  end
end
