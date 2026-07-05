defmodule ArchiDep.Servers.Ansible.RunnerClient do
  @moduledoc """
  Access to the client API of `ArchiDep.Servers.Ansible.Runner` through an
  injectable implementation.

  The Ansible context gathers facts and runs playbooks through this module
  instead of calling the `Runner` directly. In production it delegates to
  `Runner`; in the test environment it is configured to a mock so that callers
  can be tested without shelling out to Ansible.
  """

  @behaviour ArchiDep.Servers.Ansible.RunnerClientBehaviour

  @implementation Application.compile_env!(:archidep, __MODULE__)

  defdelegate gather_facts(host, port, user), to: @implementation
  defdelegate run_playbook(playbook_path, host, port, user, vars), to: @implementation
end
