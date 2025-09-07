defmodule ArchiDep.Servers.UseCases.ReadAnsible do
  @moduledoc false

  use ArchiDep, :use_case

  alias ArchiDep.Servers.Policy
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookEvent
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun

  @spec fetch_ansible_playbook_runs(Authentication.t()) :: list(AnsiblePlaybookRun.t())
  def fetch_ansible_playbook_runs(auth) do
    authorize!(auth, Policy, :servers, :fetch_ansible_playbook_runs, nil)
    AnsiblePlaybookRun.fetch_runs()
  end

  @spec fetch_ansible_playbook_run(Authentication.t(), UUID.t()) ::
          {:ok, AnsiblePlaybookRun.t()} | {:error, :ansible_playbook_run_not_found}
  def fetch_ansible_playbook_run(auth, run_id) do
    with :ok <- validate_uuid(run_id, :ansible_playbook_run_not_found),
         {:ok, run} <- AnsiblePlaybookRun.fetch_run(run_id),
         :ok <- authorize(auth, Policy, :servers, :fetch_ansible_playbook_run, nil) do
      {:ok, run}
    else
      {:error, :ansible_playbook_run_not_found} ->
        {:error, :ansible_playbook_run_not_found}

      {:error, {:access_denied, :servers, :fetch_ansible_playbook_run}} ->
        {:error, :ansible_playbook_run_not_found}
    end
  end

  @spec fetch_ansible_playbook_events_for_run(Authentication.t(), UUID.t()) ::
          {:ok, list(AnsiblePlaybookRun.t())} | {:error, :ansible_playbook_run_not_found}
  def fetch_ansible_playbook_events_for_run(auth, run_id) do
    with :ok <- validate_uuid(run_id, :ansible_playbook_run_not_found),
         {:ok, run} <- AnsiblePlaybookRun.fetch_run(run_id),
         :ok <- authorize(auth, Policy, :servers, :fetch_ansible_playbook_events_for_run, run) do
      {:ok, AnsiblePlaybookEvent.fetch_events_for_run(run_id)}
    else
      {:error, :ansible_playbook_run_not_found} ->
        {:error, :ansible_playbook_run_not_found}

      {:error, {:access_denied, :servers, :fetch_ansible_playbook_events_for_run}} ->
        {:error, :ansible_playbook_run_not_found}
    end
  end
end
