defmodule ArchiDep.Accounts.Policy do
  use ArchiDep, :policy

  alias ArchiDep.Accounts.Schemas.UserSession

  @impl Policy

  # Any authenticated user can fetch their own active sessions.
  def authorize(
        :accounts,
        :fetch_active_sessions,
        %Authentication{principal: %UserAccount{}},
        _params
      ),
      do: true

  # A root user can delete any user's session.
  def authorize(
        :accounts,
        :delete_session,
        %Authentication{principal: %UserAccount{roles: roles}},
        %UserSession{}
      ),
      do: Enum.member?(roles, :root)

  # A user can delete one of their own sessions.
  def authorize(
        :accounts,
        :delete_session,
        %Authentication{principal: %UserAccount{id: id}},
        %UserSession{
          user_account: %UserAccount{id: id}
        }
      ),
      do: true

  def authorize(_action, _principal, _params), do: false
end
