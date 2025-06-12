defmodule ArchiDep.Servers.Policy do
  use ArchiDep, :policy

  alias ArchiDep.Servers.Schemas.Server

  @impl Policy

  # Students and root users can validate servers.
  def authorize(
        :servers,
        :validate_server,
        %Authentication{principal: %UserAccount{roles: roles}},
        _params
      ),
      do: Enum.member?(roles, :student) or Enum.member?(roles, :root)

  # Students and root users can create servers.
  def authorize(
        :servers,
        :create_server,
        %Authentication{principal: %UserAccount{roles: roles}},
        _params
      ),
      do: Enum.member?(roles, :student) or Enum.member?(roles, :root)

  # Students and root users can list their servers.
  def authorize(
        :servers,
        :list_my_servers,
        %Authentication{principal: %UserAccount{roles: roles}},
        _params
      ),
      do: Enum.member?(roles, :student) or Enum.member?(roles, :root)

  # Students and root users can fetch a server that belongs to them.
  def authorize(
        :servers,
        :fetch_server,
        %Authentication{principal: %UserAccount{id: principal_id, roles: roles}},
        %Server{user_account_id: principal_id}
      ),
      do: Enum.member?(roles, :student) or Enum.member?(roles, :root)

  # Root users can fetch servers belonging to other users.
  def authorize(
        :servers,
        :fetch_server,
        %Authentication{principal: %UserAccount{roles: roles}},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can validate existing servers.
  def authorize(
        :servers,
        :validate_existing_server,
        %Authentication{principal: %UserAccount{roles: roles}},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can update servers.
  def authorize(
        :servers,
        :update_server,
        %Authentication{principal: %UserAccount{roles: roles}},
        _params
      ),
      do: Enum.member?(roles, :root)

  def authorize(_context, _action, _principal, _params), do: false
end
