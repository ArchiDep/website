defmodule ArchiDep.Servers.Policy do
  use ArchiDep, :policy

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

  def authorize(_context, _action, _principal, _params), do: false
end
