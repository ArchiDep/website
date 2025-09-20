defmodule ArchiDep.Servers.Ansible.Context do
  @moduledoc """
  Implementation of the Ansible behavior.
  """

  @behaviour ArchiDep.Servers.Ansible.Behaviour

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
  def run_playbook(
        %AnsiblePlaybookRun{state: :running} = playbook_run,
        started_cause,
        running_cause
      )
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
    |> Stream.map(&Tracker.track_playbook_event(&1, playbook_run, started_cause, running_cause))
  end

  defp playbook_path(name),
    do:
      Path.join(
        Application.app_dir(:archidep),
        PlaybooksRegistry.playbook!(name).relative_path
      )

  @impl Ansible.Behaviour
  def digest_ansible_variables(vars) when is_map(vars),
    do: :crypto.hash(:sha256, normalize_ansible_variable(vars, []))

  defp normalize_ansible_variable(nil, _path), do: "\0"

  defp normalize_ansible_variable(value, _path) when is_boolean(value) or is_number(value),
    do: to_string(value)

  defp normalize_ansible_variable(value, _path) when is_atom(value), do: Atom.to_string(value)
  defp normalize_ansible_variable(value, _path) when is_binary(value), do: value

  defp normalize_ansible_variable(value, path) when is_list(value),
    do:
      value
      |> Enum.with_index()
      |> Enum.map_join("\0", fn {v, i} ->
        normalize_ansible_variable(v, [Integer.to_string(i) | path])
      end)

  defp normalize_ansible_variable(vars, path) when is_map(vars),
    do:
      vars
      |> Enum.map(fn {k, v} -> {normalize_ansible_variable(k, []), v} end)
      |> Enum.sort_by(fn {k, _v} -> k end)
      |> Enum.flat_map(fn {k, v} ->
        [
          [k | path] |> Enum.reverse() |> Enum.join("."),
          normalize_ansible_variable(v, [k | path])
        ]
      end)
      |> Enum.join("\0")
end
