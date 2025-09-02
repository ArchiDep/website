defmodule ArchiDep.Servers.Ansible.Behaviour do
  @moduledoc false

  alias ArchiDep.Servers.Ansible.Tracker
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  alias ArchiDep.Servers.Schemas.Server

  @callback gather_facts(Server.t(), String.t()) ::
              {:ok, %{String.t() => term()}}
              | {:error, :unreachable}
              | {:error, String.t()}
              | {:error, :invalid_json_output}
              | {:error, :unknown}

  @callback run_playbook(AnsiblePlaybookRun.t()) ::
              Enumerable.t(Tracker.ansible_playbook_run_element())
end
