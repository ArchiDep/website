defmodule ArchiDep.Servers.ServerTracking.ServerManagerClient do
  @moduledoc """
  Access to the client API of
  `ArchiDep.Servers.ServerTracking.ServerManager` through an injectable
  implementation.

  Use cases call the server manager through this module instead of calling the
  GenServer directly. In production it delegates to `ServerManager`; in the test
  environment it is configured to a mock so that each use case can be tested in
  isolation.
  """

  @behaviour ArchiDep.Servers.ServerTracking.ServerManagerClientBehaviour
  @implementation Application.compile_env!(:archidep, __MODULE__)

  defdelegate retry_connecting(server), to: @implementation
  defdelegate retry_ansible_playbook(server, playbook), to: @implementation
  defdelegate retry_checking_open_ports(server), to: @implementation
  defdelegate update_server(server, auth, data), to: @implementation
  defdelegate delete_server(server, auth), to: @implementation
  defdelegate notify_server_up(server_id, event), to: @implementation
end
