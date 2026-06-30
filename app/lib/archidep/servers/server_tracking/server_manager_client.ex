defmodule ArchiDep.Servers.ServerTracking.ServerManagerClient do
  @moduledoc """
  Access to the client API of
  `ArchiDep.Servers.ServerTracking.ServerManager` through an injectable
  implementation.

  Use cases and the Ansible pipeline call the server manager through this module
  instead of calling the GenServer directly. In production it delegates to
  `ServerManager`; in the test environment it is configured to a mock so that
  callers can be tested in isolation.
  """

  @behaviour ArchiDep.Servers.ServerTracking.ServerManagerClientBehaviour
  @implementation Application.compile_env!(:archidep, __MODULE__)

  defdelegate online?(server), to: @implementation
  defdelegate ansible_facts_gathered(server, result), to: @implementation
  defdelegate ansible_playbook_event(run, event), to: @implementation
  defdelegate ansible_playbook_completed(run), to: @implementation
  defdelegate retry_connecting(server), to: @implementation
  defdelegate retry_ansible_playbook(server, playbook), to: @implementation
  defdelegate retry_checking_open_ports(server), to: @implementation
  defdelegate update_server(server, auth, data), to: @implementation
  defdelegate delete_server(server, auth), to: @implementation
  defdelegate notify_server_up(server_id, event), to: @implementation
end
