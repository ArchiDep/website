defmodule ArchiDep.Servers.Behaviour do
  @moduledoc false

  use ArchiDep, :context_behaviour

  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Servers.Types

  # Server groups
  # =============

  @doc """
  Lists all server groups.
  """
  callback(list_server_groups(auth: Authentication.t()) :: list(ServerGroup.t()))

  @doc """
  Fetches a server group.
  """
  callback(
    fetch_server_group(auth: Authentication.t(), server_group_id: UUID.t()) ::
      {:ok, ServerGroup.t()} | {:error, :server_group_not_found}
  )

  @doc """
  Watches the server IDs in a server group. Returns a tuple of the current set
  of server IDs and a function that can be used to update the set based on
  incoming messages.

  The subscriber will receive messages that are two-element tuples with the
  first element being `:server_created`, `:server_updated`, or
  `:server_deleted`, and the second element being the server that was created,
  updated or deleted.
  """
  callback(
    watch_server_ids(auth: Authentication.t(), server_group: ServerGroup.t()) ::
      {:ok, MapSet.t(UUID.t()), (MapSet.t(UUID.t()), {atom(), term()} -> MapSet.t(UUID.t()))}
      | {:error, :unauthorized}
  )

  # Server group members
  # ====================

  @doc """
  Lists all members of a server group.
  """
  callback(
    list_server_group_members(auth: Authentication.t(), server_group_id: UUID.t()) ::
      {:ok, list(ServerGroupMember.t())} | {:error, :server_group_not_found}
  )

  @doc """
  Fetches the authenticated server group member.
  """
  callback(
    fetch_authenticated_server_group_member(auth: Authentication.t()) ::
      {:ok, ServerGroupMember.t()} | {:error, :not_a_server_group_member}
  )

  # Servers
  # =======

  @doc """
  Validates the data to create a new server.
  """
  callback(
    validate_server(auth: Authentication.t(), data: Types.create_server_data()) :: Changeset.t()
  )

  @doc """
  Creates a new server.
  """
  callback(
    create_server(auth: Authentication.t(), data: Types.create_server_data()) ::
      {:ok, Server.t()} | {:error, Changeset.t()}
  )

  @doc """
  Lists all servers owned by the authenticated user.
  """
  callback(list_my_servers(auth: Authentication.t()) :: list(Server.t()))

  @doc """
  Lists all active servers owned by the authenticated user.
  """
  callback(list_my_active_servers(auth: Authentication.t()) :: list(Server.t()))

  @doc """
  Lists all servers in a server group.
  """
  callback(
    list_all_servers_in_group(auth: Authentication.t(), server_group_id: UUID.t()) ::
      {:ok, list(Server.t())} | {:error, :server_group_not_found}
  )

  @doc """
  Fetches a server.
  """
  callback(
    fetch_server(auth: Authentication.t(), server_id: UUID.t()) ::
      {:ok, Server.t()} | {:error, :server_not_found}
  )

  @doc """
  Validates the data to update an existing server.
  """
  callback(
    validate_existing_server(
      auth: Authentication.t(),
      server_id: UUID.t(),
      data: Types.update_server_data()
    ) ::
      {:ok, Changeset.t()} | {:error, :server_not_found}
  )

  @doc """
  Updates a server. The operation will fail if the server is busy.
  """
  callback(
    update_server(auth: Authentication.t(), server_id: UUID.t(), data: Types.update_server_data()) ::
      {:ok, Server.t()}
      | {:error, Changeset.t()}
      | {:error, :server_busy}
      | {:error, :server_not_found}
  )

  @doc """
  Deletes a server. The operation will fail if the server is busy.
  """
  callback(
    delete_server(auth: Authentication.t(), server_id: UUID.t()) ::
      :ok | {:error, :server_busy} | {:error, :server_not_found}
  )

  # Connected servers
  # =================

  @doc """
  Retry opening the connection to a server.
  """
  callback(
    retry_connecting(auth: Authentication.t(), server_id: UUID.t()) ::
      :ok | {:error, :server_not_found}
  )

  @doc """
  Retry running an Ansible playbook on a server.
  """
  callback(
    retry_ansible_playbook(auth: Authentication.t(), server_id: UUID.t(), playbook: String.t()) ::
      :ok | {:error, :server_not_found} | {:error, :server_not_connected} | {:error, :server_busy}
  )

  @doc """
  Retry checking the open ports on a server.
  """
  callback(
    retry_checking_open_ports(auth: Authentication.t(), server_id: UUID.t()) ::
      :ok | {:error, :server_not_found} | {:error, :server_not_connected} | {:error, :server_busy}
  )

  @doc """
  Receive a notification that a server is up. This is used to automatically
  attempt to connect to a server as soon as it boots.
  """
  callback(
    notify_server_up(server_id: UUID.t(), token: binary()) ::
      :ok | {:error, :server_not_found}
  )
end
