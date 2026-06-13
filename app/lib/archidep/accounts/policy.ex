defmodule ArchiDep.Accounts.Policy do
  @moduledoc """
  Authorization policy for user account management actions.
  """

  use ArchiDep, :policy

  alias ArchiDep.Accounts.Schemas.UserSession

  @impl Policy

  # Root users can impersonate any user except themselves.
  def authorize(
        :accounts,
        :impersonate,
        %Authentication{principal_id: principal_id, root: true},
        %UserAccount{id: impersonated_user_id}
      ),
      do: principal_id != impersonated_user_id

  # Only a user who is currently impersonating another user can stop
  # impersonating — including root users, so this clause must come before the
  # root catch-all below (otherwise a root user who is not impersonating would
  # be authorized to "stop", with nothing to stop).
  def authorize(
        :accounts,
        :stop_impersonating,
        %Authentication{
          impersonated_id: impersonated_id
        },
        _params
      ),
      do: impersonated_id != nil

  # Root users can perform any other action.
  def authorize(
        :accounts,
        _action,
        %Authentication{root: true},
        _params
      ),
      do: true

  # Any authenticated user can fetch their own active sessions.
  def authorize(
        :accounts,
        :fetch_active_sessions,
        %Authentication{},
        _params
      ),
      do: true

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

  def authorize(_context, _action, _auth, _params), do: false
end
