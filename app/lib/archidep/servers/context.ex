defmodule ArchiDep.Servers.Context do
  @moduledoc false

  use ArchiDep, :context_impl

  @behaviour ArchiDep.Servers.Behaviour

  alias ArchiDep.Servers.Behaviour

  # Server groups
  # =============

  implement(&Behaviour.list_server_groups/1, ArchiDep.Servers.ReadServerGroups)

  implement(
    &Behaviour.fetch_server_group/2,
    ArchiDep.Servers.ReadServerGroups
  )

  implement(
    &Behaviour.validate_server_group_expected_properties/3,
    ArchiDep.Servers.UpdateServerGroupExpectedProperties
  )

  implement(
    &Behaviour.update_server_group_expected_properties/3,
    ArchiDep.Servers.UpdateServerGroupExpectedProperties
  )

  implement(&Behaviour.watch_server_ids/2, ArchiDep.Servers.ReadServerGroups)

  # Server group members
  # ====================

  implement(
    &Behaviour.list_server_group_members/2,
    ArchiDep.Servers.ReadServerGroups
  )

  implement(
    &Behaviour.fetch_authenticated_server_group_member/1,
    ArchiDep.Servers.ReadServerGroups
  )

  # Servers
  # =======

  implement(&Behaviour.validate_server/2, ArchiDep.Servers.CreateServer)
  implement(&Behaviour.create_server/2, ArchiDep.Servers.CreateServer)
  implement(&Behaviour.list_my_servers/1, ArchiDep.Servers.ReadServers)

  implement(
    &Behaviour.fetch_server/2,
    ArchiDep.Servers.ReadServers
  )

  implement(
    &Behaviour.validate_existing_server/3,
    ArchiDep.Servers.UpdateServer
  )

  implement(
    &Behaviour.update_server/3,
    ArchiDep.Servers.UpdateServer
  )

  implement(
    &Behaviour.delete_server/2,
    ArchiDep.Servers.DeleteServer
  )

  # Connected servers
  # =================

  implement(&Behaviour.retry_connecting/2, ArchiDep.Servers.ManageServer)
  implement(&Behaviour.retry_ansible_playbook/3, ArchiDep.Servers.ManageServer)
  implement(&Behaviour.notify_server_up/2, ArchiDep.Servers.ServerCallbacks)
end
