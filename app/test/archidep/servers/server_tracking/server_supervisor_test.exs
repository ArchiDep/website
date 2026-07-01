defmodule ArchiDep.Servers.ServerTracking.ServerSupervisorTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Servers.Ansible.Pipeline
  alias ArchiDep.Servers.ServerTracking.ServerConnection
  alias ArchiDep.Servers.ServerTracking.ServerManager
  alias ArchiDep.Servers.ServerTracking.ServerManagerState
  alias ArchiDep.Servers.ServerTracking.ServerSupervisor
  alias Ecto.UUID

  test "supervises a server's manager and connection with rest-for-one restarts" do
    server_id = UUID.generate()

    assert {:ok, {flags, [manager_spec, connection_spec]}} =
             ServerSupervisor.init({server_id, Pipeline})

    assert flags == %{
             strategy: :rest_for_one,
             intensity: 3,
             period: 5,
             auto_shutdown: :all_significant
           }

    # The `ServerManager` child carries a state-module factory (a closure) that
    # cannot be compared by equality, so it is bound, its result asserted, and
    # then reused to pin each whole child spec by equality.
    assert %{start: {ServerManager, :start_link, [_id, _pipeline, [state: state_factory]]}} =
             manager_spec

    assert state_factory.() == ServerManagerState

    assert manager_spec == %{
             id: ServerManager,
             restart: :transient,
             significant: true,
             start: {ServerManager, :start_link, [server_id, Pipeline, [state: state_factory]]}
           }

    assert connection_spec == %{
             id: ServerConnection,
             start: {ServerConnection, :start_link, [server_id]}
           }
  end
end
