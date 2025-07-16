defmodule ArchiDep.Servers.Context do
  @moduledoc false

  use ArchiDep, :context_impl

  @behaviour ArchiDep.Servers.Behaviour

  alias ArchiDep.Servers.Behaviour
  alias ArchiDep.Servers.UseCases

  # Server groups
  # =============

  implement(&Behaviour.list_server_groups/1, UseCases.ReadServerGroups)
  implement(&Behaviour.fetch_server_group/2, UseCases.ReadServerGroups)
  implement(&Behaviour.watch_server_ids/2, UseCases.ReadServerGroups)

  # Server group members
  # ====================

  implement(&Behaviour.list_server_group_members/2, UseCases.ReadServerGroups)

  implement(&Behaviour.fetch_authenticated_server_group_member/1, UseCases.ReadServerGroups)

  # Servers
  # =======

  implement(&Behaviour.validate_server/2, UseCases.CreateServer)
  implement(&Behaviour.create_server/2, UseCases.CreateServer)
  implement(&Behaviour.list_my_servers/1, UseCases.ReadServers)
  implement(&Behaviour.fetch_server/2, UseCases.ReadServers)
  implement(&Behaviour.validate_existing_server/3, UseCases.UpdateServer)
  implement(&Behaviour.update_server/3, UseCases.UpdateServer)
  implement(&Behaviour.delete_server/2, UseCases.DeleteServer)

  # Connected servers
  # =================

  implement(&Behaviour.retry_connecting/2, UseCases.ManageServer)
  implement(&Behaviour.retry_ansible_playbook/3, UseCases.ManageServer)
  implement(&Behaviour.notify_server_up/2, UseCases.ServerCallbacks)
end
