defmodule ArchiDepWeb.Helpers.AuthHelpers do
  @moduledoc """
  Authentication-related helpers for the web application.
  """

  alias ArchiDep.Accounts.Schemas.UserAccount
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Accounts.Types
  alias ArchiDep.Authentication

  @spec logged_in?(Authentication.t()) :: boolean()
  def logged_in?(nil), do: false
  def logged_in?(_auth), do: true

  @spec has_role?(Authentication.t(), Types.role()) :: boolean()
  def has_role?(nil, _role), do: false
  def has_role?(auth, role), do: Authentication.has_role?(auth, role)

  @spec can_impersonate?(Authentication.t(), UserAccount.t()) :: boolean()
  def can_impersonate?(nil, _user_account), do: false

  def can_impersonate?(
        %Authentication{
          principal_id: principal_id,
          impersonated_id: impersonated_id
        },
        %UserAccount{id: user_account_id}
      ),
      do: impersonated_id == nil and user_account_id != principal_id

  @spec is_impersonating?(Authentication.t()) :: boolean()
  def is_impersonating?(nil), do: false

  def is_impersonating?(%Authentication{impersonated_id: nil}),
    do: false

  def is_impersonating?(_auth), do: true

  @spec username(Authentication.t()) :: String.t()
  defdelegate username(auth), to: Authentication
end
