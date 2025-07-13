defmodule ArchiDep.Servers.ContextImpl do
  use ArchiDep, :context

  alias ArchiDep.Servers.ConfigureServerGroupMember
  alias ArchiDep.Servers.CreateServer
  alias ArchiDep.Servers.DeleteServer
  alias ArchiDep.Servers.ManageServer
  alias ArchiDep.Servers.ReadServerGroups
  alias ArchiDep.Servers.ReadServers
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Servers.Schemas.ServerProperties
  alias ArchiDep.Servers.ServerCallbacks
  alias ArchiDep.Servers.Types
  alias ArchiDep.Servers.UpdateServer
  alias ArchiDep.Servers.UpdateServerGroupExpectedProperties

  @behaviour ArchiDep.Servers.Behaviour

  # Server groups

  @spec list_server_groups(Authentication.t()) :: list(ServerGroup.t())
  defdelegate list_server_groups(auth), to: ReadServerGroups

  @spec fetch_server_group(Authentication.t(), UUID.t()) ::
          {:ok, ServerGroup.t()} | {:error, :server_group_not_found}
  defdelegate fetch_server_group(auth, id), to: ReadServerGroups

  @spec validate_server_group_expected_properties(
          Authentication.t(),
          UUID.t(),
          Types.server_properties_data()
        ) ::
          {:ok, Changeset.t()}
          | {:error, :server_group_not_found}
  defdelegate validate_server_group_expected_properties(auth, id, data),
    to: UpdateServerGroupExpectedProperties

  @spec update_server_group_expected_properties(
          Authentication.t(),
          UUID.t(),
          Types.server_properties_data()
        ) ::
          {:ok, ServerProperties.t()}
          | {:error, Changeset.t()}
          | {:error, :server_group_not_found}
  defdelegate update_server_group_expected_properties(auth, id, data),
    to: UpdateServerGroupExpectedProperties

  @spec watch_server_ids(Authentication.t(), ServerGroup.t()) ::
          {:ok, MapSet.t(UUID.t()), (MapSet.t(UUID.t()), {atom(), term()} -> MapSet.t(UUID.t()))}
          | {:error, :unauthorized}
  defdelegate watch_server_ids(auth, group), to: ReadServerGroups

  # Server group members

  @spec list_server_group_members(Authentication.t(), UUID.t()) ::
          {:ok, list(ServerGroupMember.t())} | {:error, :server_group_not_found}
  defdelegate list_server_group_members(auth, id), to: ReadServerGroups

  @spec fetch_authenticated_server_group_member(Authentication.t()) ::
          {:ok, ServerGroupMember.t()} | {:error, :not_a_server_group_member}
  defdelegate fetch_authenticated_server_group_member(auth), to: ReadServerGroups

  @spec fetch_server_group_member(Authentication.t(), UUID.t()) ::
          {:ok, ServerGroupMember.t()} | {:error, :server_group_member_not_found}
  defdelegate fetch_server_group_member(auth, id), to: ReadServerGroups

  @spec validate_server_group_member_config(
          Authentication.t(),
          UUID.t(),
          Types.server_group_member_config()
        ) ::
          {:ok, Changeset.t()} | {:error, :server_group_member_not_found}
  defdelegate validate_server_group_member_config(auth, id, data),
    to: ConfigureServerGroupMember

  @spec configure_server_group_member(
          Authentication.t(),
          UUID.t(),
          Types.server_group_member_config()
        ) ::
          {:ok, ServerGroupMember.t()}
          | {:error, Changeset.t()}
          | {:error, :server_group_member_not_found}
  defdelegate configure_server_group_member(auth, id, data),
    to: ConfigureServerGroupMember

  # Servers

  @spec validate_server(Authentication.t(), Types.create_server_data()) :: Changeset.t()
  defdelegate validate_server(auth, data), to: CreateServer

  @spec create_server(Authentication.t(), Types.create_server_data()) ::
          {:ok, Server.t()} | {:error, Changeset.t()}
  defdelegate create_server(auth, data), to: CreateServer

  @spec list_my_servers(Authentication.t()) :: list(Server.t())
  defdelegate list_my_servers(auth), to: ReadServers

  @spec fetch_server(Authentication.t(), UUID.t()) ::
          {:ok, Server.t()} | {:error, :server_not_found}
  defdelegate fetch_server(auth, id), to: ReadServers

  @spec validate_existing_server(Authentication.t(), UUID.t(), Types.update_server_data()) ::
          {:ok, Changeset.t()} | {:error, :server_not_found}
  defdelegate validate_existing_server(auth, id, data), to: UpdateServer

  @spec update_server(Authentication.t(), UUID.t(), Types.update_server_data()) ::
          {:ok, Server.t()}
          | {:error, Changeset.t()}
          | {:error, :server_busy}
          | {:error, :server_not_found}
  defdelegate update_server(auth, id, data), to: UpdateServer

  @spec delete_server(Authentication.t(), UUID.t()) ::
          :ok | {:error, :server_busy} | {:error, :server_not_found}
  defdelegate delete_server(auth, server_id), to: DeleteServer

  # Connected servers

  @spec retry_connecting(Authentication.t(), UUID.t()) ::
          :ok | {:error, :server_not_found}
  defdelegate retry_connecting(auth, server), to: ManageServer

  @spec retry_ansible_playbook(Authentication.t(), UUID.t(), String.t()) ::
          :ok | {:error, :server_not_found}
  defdelegate retry_ansible_playbook(auth, server, playbook), to: ManageServer

  @spec notify_server_up(UUID.t(), binary()) :: :ok | {:error, :server_not_found}
  defdelegate notify_server_up(server_id, nonce), to: ServerCallbacks
end
