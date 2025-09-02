defmodule ArchiDep.Servers.Ansible.Context do
  @moduledoc """
  Implementation of the Ansible behavior.
  """

  @behaviour Ansible.Behaviour

  alias ArchiDep.Servers.Ansible
  alias ArchiDep.Servers.Ansible.PlaybooksRegistry
  alias ArchiDep.Servers.Ansible.Runner
  alias ArchiDep.Servers.Ansible.Tracker
  alias ArchiDep.Servers.Schemas.AnsiblePlaybookRun
  require Logger

  @impl Ansible.Behaviour
  def gather_facts(server, ansible_user) do
    ansible_host = server.ip_address.address
    ansible_port = server.ssh_port || 22
    Runner.gather_facts(ansible_host, ansible_port, ansible_user)
  end

  @impl Ansible.Behaviour
  def run_playbook(%AnsiblePlaybookRun{state: :running} = playbook_run)
      when is_struct(playbook_run, AnsiblePlaybookRun) do
    ansible_host = playbook_run.host.address
    ansible_port = playbook_run.port
    ansible_user = playbook_run.user

    Logger.info(
      "Running Ansible playbook #{playbook_run.playbook} on server #{playbook_run.server.id} (#{ansible_user}@#{:inet.ntoa(ansible_host)}:#{ansible_port})"
    )

    playbook_run.playbook
    |> playbook_path()
    |> Runner.run_playbook(
      ansible_host,
      ansible_port,
      ansible_user,
      playbook_run.vars
    )
    |> Stream.map(&Tracker.track_playbook_event(&1, playbook_run))
  end

  defp playbook_path(name),
    do:
      Path.join(
        Application.app_dir(:archidep),
        PlaybooksRegistry.playbook!(name).relative_path
      )
end
