defmodule ArchiDep.Servers.Ansible do
  require Logger
  alias ArchiDep.Servers.Ansible.PlaybooksRegistry
  alias ArchiDep.Servers.Ansible.Runner
  alias ArchiDep.Servers.Ansible.Tracker
  alias ArchiDep.Servers.Schemas.AnsiblePlaybook
  alias ArchiDep.Servers.Schemas.Server

  @app_user_playbook PlaybooksRegistry.playbook!("app-user")

  @spec app_user_playbook :: AnsiblePlaybook.t()
  def app_user_playbook, do: @app_user_playbook

  @spec gather_facts(Server.t(), String.t()) ::
          {:ok, %{String.t() => term()}}
          | {:error, :unreachable}
          | {:error, String.t()}
          | {:error, :invalid_json_output}
          | {:error, :unknown}
  def gather_facts(server, ansible_user) do
    ansible_host = server.ip_address.address
    ansible_port = server.ssh_port || 22
    Runner.gather_facts(ansible_host, ansible_port, ansible_user)
  end

  @spec run_playbook(AnsiblePlaybook.t(), Server.t(), String.t(), Runner.ansible_variables()) ::
          Enumerable.t(Tracker.ansible_playbook_run_element())
  def run_playbook(playbook, server, user, vars)
      when is_struct(playbook, AnsiblePlaybook) and is_struct(server, Server) and is_binary(user) and
             is_map(vars) do
    run = Tracker.track_playbook!(playbook, server, user)

    playbook
    |> Runner.run_playbook(run.host.address, run.port, run.user, vars)
    |> Stream.map(&Tracker.track_playbook_event(&1, run))
    |> Stream.run()
  end
end
