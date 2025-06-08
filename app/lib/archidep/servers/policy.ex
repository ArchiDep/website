defmodule ArchiDep.Servers.Policy do
  use ArchiDep, :policy

  @impl Policy

  # Root users can validate servers.
  def authorize(
        :servers,
        :validate_server,
        %Authentication{principal: %UserAccount{roles: roles}},
        _params
      ),
      do: Enum.member?(roles, :root)

  # Root users can create servers.
  def authorize(
        :servers,
        :create_server,
        %Authentication{principal: %UserAccount{roles: roles}},
        _params
      ),
      do: Enum.member?(roles, :root)

  def authorize(_context, _action, _principal, _params), do: false
end
