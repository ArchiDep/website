defmodule ArchiDep.Servers.Policy do
  @moduledoc """
  Authorization policy for server-related actions in ArchiDep.
  """

  use ArchiDep, :policy

  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerGroup
  alias ArchiDep.Servers.Schemas.ServerGroupMember
  alias ArchiDep.Servers.Schemas.ServerOwner

  @impl Policy

  # Root users can perform any action.
  def authorize(
        :servers,
        _action,
        %Authentication{root: true},
        _params
      ),
      do: true

  # Any user can fetch their authenticated server group member.
  def authorize(
        :servers,
        :fetch_authenticated_server_group_member,
        %Authentication{},
        _params
      ),
      do: true

  # Server group members can validate servers for their own group.
  def authorize(
        :servers,
        :validate_server,
        %Authentication{root: false},
        {_data, %ServerGroup{id: group_id},
         %ServerOwner{group_member: %ServerGroupMember{group_id: group_id}}}
      ),
      do: true

  # Server group members can create servers in their own group.
  def authorize(
        :servers,
        :create_server,
        %Authentication{root: false},
        {_data, %ServerGroup{id: group_id},
         %ServerOwner{group_member: %ServerGroupMember{group_id: group_id}}}
      ),
      do: true

  # Server group members can list their own servers.
  def authorize(
        :servers,
        :list_my_servers,
        %Authentication{root: false},
        _params
      ),
      do: true

  # Server group members can list their own active servers.
  def authorize(
        :servers,
        :list_my_active_servers,
        %Authentication{root: false},
        _params
      ),
      do: true

  # Server group members can fetch a server that belongs to them.
  def authorize(
        :servers,
        :fetch_server,
        %Authentication{principal_id: principal_id, root: false},
        %Server{owner_id: principal_id}
      ),
      do: true

  # Server group members can retry connecting to their own servers.
  def authorize(
        :servers,
        :retry_connecting,
        %Authentication{principal_id: principal_id, root: false},
        %Server{owner_id: principal_id}
      ),
      do: true

  # Server group members can retry checking open ports on their own servers.
  def authorize(
        :servers,
        :retry_checking_open_ports,
        %Authentication{principal_id: principal_id, root: false},
        %Server{owner_id: principal_id}
      ),
      do: true

  # Server group members can validate their own existing servers.
  def authorize(
        :servers,
        :validate_existing_server,
        %Authentication{principal_id: principal_id, root: false},
        %Server{owner_id: principal_id}
      ),
      do: true

  # Server group members can update their own servers.
  def authorize(
        :servers,
        :update_server,
        %Authentication{principal_id: principal_id, root: false},
        %Server{owner_id: principal_id}
      ),
      do: true

  def authorize(_context, _action, _auth, _params), do: false
end
