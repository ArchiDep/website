defmodule ArchiDep.Servers.Ansible do
  require Logger
  alias ArchiDep.Servers.Ansible.PlaybooksRegistry
  alias ArchiDep.Servers.Ansible.Runner
  alias ArchiDep.Servers.Ansible.Tracker
  alias ArchiDep.Servers.Schemas.AnsiblePlaybook
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
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

  @spec run_playbook(AnsiblePlaybookRun.t()) ::
          Enumerable.t(Tracker.ansible_playbook_run_element())
  def run_playbook(%AnsiblePlaybookRun{state: :pending} = playbook_run)
      when is_struct(playbook_run, AnsiblePlaybookRun) do
    Logger.info(
      "Running Ansible playbook #{playbook_run.playbook} on server #{playbook_run.server.id}"
    )

    playbook_run.playbook
    |> playbook_path()
    |> Runner.run_playbook(
      playbook_run.host.address,
      playbook_run.port,
      playbook_run.user,
      playbook_run.vars
    )
    |> Stream.map(&Tracker.track_playbook_event(&1, playbook_run))
    |> Stream.run()
  end

  defp playbook_path(name),
    do:
      Path.join(
        Application.app_dir(:archidep),
        PlaybooksRegistry.playbook!(name).relative_path
      )
end
