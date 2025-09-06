defmodule ArchiDep.Servers.UseCases.ReadAnsible do
  use ArchiDep, :use_case

  alias ArchiDep.Servers.Policy
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun

  @spec fetch_ansible_playbook_runs(Authentication.t()) :: list(AnsiblePlaybookRun.t())
  def fetch_ansible_playbook_runs(auth) do
    authorize!(auth, Policy, :servers, :fetch_ansible_playbook_runs, nil)
    AnsiblePlaybookRun.fetch_runs()
  end
end
