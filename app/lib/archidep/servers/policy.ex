defmodule ArchiDep.Servers.Policy do
  use ArchiDep, :policy

  alias ArchiDep.Servers.Schemas.Server

  @impl Policy

  # Root users can list server groups.
  def authorize(
        :servers,
        :list_server_groups,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can fetch a server group.
  def authorize(
        :servers,
        :fetch_server_group,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Server group members can validate servers for their own group.
  def authorize(
        :servers,
        :validate_server,
        %Authentication{roles: roles},
        %{group_id: nil}
      ),
      do: Enum.member?(roles, :student)

  # Root users can validate any server.
  def authorize(
        :servers,
        :validate_server,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Server group members can create servers in their own group.
  def authorize(
        :servers,
        :create_server,
        %Authentication{roles: roles},
        %{group_id: nil}
      ),
      do: Enum.member?(roles, :student)

  # Root users can create any server.
  def authorize(
        :servers,
        :create_server,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :student) or Enum.member?(roles, :root)

  # Server group members and root users can list their own servers.
  def authorize(
        :servers,
        :list_my_servers,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :student) or Enum.member?(roles, :root)

  # Server group members and root users can fetch a server that belongs to them.
  def authorize(
        :servers,
        :fetch_server,
        %Authentication{principal_id: principal_id, roles: roles},
        %Server{owner_id: principal_id}
      ),
      do: Enum.member?(roles, :student) or Enum.member?(roles, :root)

  # Root users can fetch servers belonging to other users.
  def authorize(
        :servers,
        :fetch_server,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Server group members can retry connecting to their own servers.
  def authorize(
        :servers,
        :retry_connecting,
        %Authentication{principal_id: principal_id, roles: roles},
        %Server{owner_id: principal_id}
      ),
      do: Enum.member?(roles, :student) or Enum.member?(roles, :root)

  # Root users can retry connecting to any server.
  def authorize(
        :servers,
        :retry_connecting,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can retry running ansible playbooks.
  def authorize(
        :servers,
        :retry_ansible_playbook,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Server group members and root users can validate their own existing servers.
  def authorize(
        :servers,
        :validate_existing_server,
        %Authentication{principal_id: principal_id, roles: roles},
        %Server{owner_id: principal_id}
      ),
      do: Enum.member?(roles, :student) or Enum.member?(roles, :root)

  # Root users can validate any existing server.
  def authorize(
        :servers,
        :validate_existing_server,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Server group members and root users can update their own servers.
  def authorize(
        :servers,
        :update_server,
        %Authentication{principal_id: principal_id, roles: roles},
        %Server{owner_id: principal_id}
      ),
      do: Enum.member?(roles, :student) or Enum.member?(roles, :root)

  # Root users can update any server.
  def authorize(
        :servers,
        :update_server,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can delete servers.
  def authorize(
        :servers,
        :delete_server,
        %Authentication{roles: roles},
        _params
      ),
      do: Enum.member?(roles, :root)

  def authorize(_context, _action, _principal, _params), do: false
end
