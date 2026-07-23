defmodule ArchiDep.Servers.Context do
  @moduledoc false

  @behaviour ArchiDep.Servers.Behaviour

  alias ArchiDep.Servers.Behaviour
  alias ArchiDep.Servers.UseCases

  # Server groups
  # =============

  @doc false
  @impl Behaviour
  defdelegate list_server_groups(auth), to: UseCases.ReadServerGroups

  @doc false
  @impl Behaviour
  defdelegate fetch_server_group(auth, server_group_id), to: UseCases.ReadServerGroups

  @doc false
  @impl Behaviour
  defdelegate subscribe_server_group_servers(auth, server_group), to: UseCases.ReadServerGroups

  @doc false
  @impl Behaviour
  defdelegate refresh_server_ids(server_ids, message), to: UseCases.ReadServerGroups

  @doc false
  @impl Behaviour
  defdelegate list_all_servers_in_group(auth, server_group_id), to: UseCases.ReadServerGroups

  # Server group members
  # ====================

  @doc false
  @impl Behaviour
  defdelegate list_server_group_members(auth, server_group_id), to: UseCases.ReadServerGroups

  @doc false
  @impl Behaviour
  defdelegate fetch_authenticated_server_group_member(auth), to: UseCases.ReadServerGroups

  @doc false
  @impl Behaviour
  defdelegate fetch_authenticated_server_owner(auth), to: UseCases.ReadServerGroups

  # Servers
  # =======

  @doc false
  @impl Behaviour
  defdelegate validate_server(auth, group_id, data), to: UseCases.CreateServer

  @doc false
  @impl Behaviour
  defdelegate create_server(auth, group_id, data), to: UseCases.CreateServer

  @doc false
  @impl Behaviour
  defdelegate list_my_servers(auth), to: UseCases.ReadServers

  @doc false
  @impl Behaviour
  defdelegate subscribe_my_servers(auth), to: UseCases.ReadServers

  @doc false
  @impl Behaviour
  defdelegate refresh_my_servers(auth, servers, message), to: UseCases.ReadServers

  @doc false
  @impl Behaviour
  defdelegate refresh_server_state_map(server_state_map, message), to: UseCases.ReadServers

  @doc false
  @impl Behaviour
  defdelegate fetch_server(auth, server_id), to: UseCases.ReadServers

  @doc false
  @impl Behaviour
  defdelegate fetch_active_server_for_group_member(auth, group_member_id),
    to: UseCases.ReadServers

  @doc false
  @impl Behaviour
  defdelegate subscribe_server(server), to: UseCases.ReadServers

  @doc false
  @impl Behaviour
  defdelegate refresh_server(server, message), to: UseCases.ReadServers

  @doc false
  @impl Behaviour
  defdelegate subscribe_active_server_for_member(owner_id), to: UseCases.ReadServers

  @doc false
  @impl Behaviour
  defdelegate refresh_active_server_for_member(auth, member_id, current, message),
    to: UseCases.ReadServers

  @doc false
  @impl Behaviour
  defdelegate validate_existing_server(auth, server_id, data), to: UseCases.UpdateServer

  @doc false
  @impl Behaviour
  defdelegate update_server(auth, server_id, data), to: UseCases.UpdateServer

  @doc false
  @impl Behaviour
  defdelegate delete_server(auth, server_id), to: UseCases.DeleteServer

  # Connected servers
  # =================

  @doc false
  @impl Behaviour
  defdelegate retry_connecting(auth, server_id), to: UseCases.ManageServer

  @doc false
  @impl Behaviour
  defdelegate retry_ansible_playbook(auth, server_id, playbook), to: UseCases.ManageServer

  @doc false
  @impl Behaviour
  defdelegate retry_checking_open_ports(auth, server_id), to: UseCases.ManageServer

  @doc false
  @impl Behaviour
  defdelegate notify_server_up(server_id, token), to: UseCases.ServerCallbacks

  # Ansible
  # =======

  @doc false
  @impl Behaviour
  defdelegate fetch_ansible_playbook_runs(auth), to: UseCases.ReadAnsible

  @doc false
  @impl Behaviour
  defdelegate fetch_ansible_playbook_run(auth, run_id), to: UseCases.ReadAnsible

  @doc false
  @impl Behaviour
  defdelegate fetch_ansible_playbook_events_for_run(auth, run_id), to: UseCases.ReadAnsible

  @doc false
  @impl Behaviour
  defdelegate subscribe_ansible_playbook_runs(), to: UseCases.ReadAnsible

  @doc false
  @impl Behaviour
  defdelegate tracked_ansible_playbook_runs(), to: UseCases.ReadAnsible

  @doc false
  @impl Behaviour
  defdelegate refresh_ansible_playbook_runs(auth, playbook_runs, tracked_playbooks, message),
    to: UseCases.ReadAnsible
end
