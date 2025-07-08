defmodule ArchiDep.Accounts.Policy do
  use ArchiDep, :policy

  alias ArchiDep.Accounts.Schemas.UserSession

  @impl Policy

  # Any authenticated user can fetch their own active sessions.
  def authorize(
        :accounts,
        :fetch_active_sessions,
        %Authentication{principal: %UserAccount{active: true}},
        _params
      ),
      do: true

  # Root users can impersonate any user except themselves.
  def authorize(
        :accounts,
        :impersonate,
        %Authentication{principal: %UserAccount{id: principal_id, active: true, roles: roles}},
        %UserAccount{id: impersonated_user_id}
      )
      when principal_id != impersonated_user_id,
      do: Enum.member?(roles, :root)

  # A user who is currently impersonating another user can stop impersonating.
  def authorize(
        :accounts,
        :stop_impersonating,
        %Authentication{
          session: %UserSession{impersonated_user_account_id: impersonated_user_account_id}
        },
        _params
      ),
      do: impersonated_user_account_id != nil

  # A root user can delete any user's session.
  def authorize(
        :accounts,
        :delete_session,
        %Authentication{principal: %UserAccount{active: true, roles: roles}},
        %UserSession{}
      ),
      do: Enum.member?(roles, :root)

  # A user can delete one of their own sessions.
  def authorize(
        :accounts,
        :delete_session,
        %Authentication{principal: %UserAccount{id: id, active: true}},
        %UserSession{
          user_account: %UserAccount{id: id}
        }
      ),
      do: true

  def authorize(_context, _action, _principal, _params), do: false
end
