defmodule ArchiDep.Accounts.Policy do
  use ArchiDep, :policy

  alias ArchiDep.Accounts.Schemas.UserSession

  @impl Policy

  # Any authenticated user can fetch their own active sessions.
  def authorize(
        :accounts,
        :fetch_active_sessions,
        %Authentication{},
        _params
      ),
      do: true

  # Root users can impersonate any user except themselves.
  def authorize(
        :accounts,
        :impersonate,
        %Authentication{principal_id: principal_id, roles: roles},
        %UserAccount{id: impersonated_user_id}
      )
      when principal_id != impersonated_user_id,
      do: Enum.member?(roles, :root)

  # A user who is currently impersonating another user can stop impersonating.
  def authorize(
        :accounts,
        :stop_impersonating,
        %Authentication{
          impersonated_id: impersonated_id
        },
        _params
      ),
      do: impersonated_id != nil

  # A root user can delete any user's session.
  def authorize(
        :accounts,
        :delete_session,
        %Authentication{roles: roles},
        %UserSession{}
      ),
      do: Enum.member?(roles, :root)

  # A user can delete one of their own sessions.
  def authorize(
        :accounts,
        :delete_session,
        %Authentication{principal_id: principal_id},
        %UserSession{
          user_account: %UserAccount{id: principal_id}
        }
      ),
      do: true

  def authorize(_context, _action, _principal, _params), do: false
end
