defmodule ArchiDep.Servers.Ansible.RunnerClientBehaviour do
  @moduledoc """
  Behaviour of the client API of `ArchiDep.Servers.Ansible.Runner` used to
  gather facts and run playbooks on remote servers through the Ansible command
  line interface.

  It is implemented in production by the `Runner` module and swapped for a mock
  in the test environment so that callers such as the `Ansible.Context` can be
  tested without shelling out to Ansible.
  """

  alias ArchiDep.Servers.Ansible.Runner
  alias ArchiDep.Servers.Types

  @callback gather_facts(Types.ansible_host(), Types.ansible_port(), Types.ansible_user()) ::
              {:ok, %{String.t() => term()}}
              | {:error, :unreachable}
              | {:error, String.t()}
              | {:error, :invalid_json_output}
              | {:error, :unknown}

  @callback run_playbook(
              String.t(),
              Types.ansible_host(),
              Types.ansible_port(),
              Types.ansible_user(),
              Types.ansible_variables()
            ) :: Enumerable.t(Runner.ansible_playbook_run_element())
end
