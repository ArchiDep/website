defmodule ArchiDep.Servers.Ansible do
  @moduledoc """
  Ansible module that provides functions to interact with Ansible playbooks
  and run them on remote servers.

  See https://docs.ansible.com.
  """

  @behaviour ArchiDep.Servers.Ansible.Behaviour

  alias ArchiDep.Servers.Ansible.PlaybooksRegistry
  alias ArchiDep.Servers.Schemas.AnsiblePlaybook
  require Logger

  @implementation Application.compile_env!(:archidep, __MODULE__)
  @setup_playbook PlaybooksRegistry.playbook!("setup")

  @spec playbook!(String.t()) :: AnsiblePlaybook.t()
  def playbook!("setup"), do: @setup_playbook

  @spec setup_playbook() :: AnsiblePlaybook.t()
  def setup_playbook, do: @setup_playbook

  defdelegate gather_facts(server, ansible_user), to: @implementation
  defdelegate run_playbook(playbook_run, started_cause, running_cause), to: @implementation
end
