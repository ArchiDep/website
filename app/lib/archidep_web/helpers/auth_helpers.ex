defmodule ArchiDepWeb.Helpers.AuthHelpers do
  @moduledoc """
  Authentication-related helpers for the web application.
  """

  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Accounts.Types
  alias ArchiDep.Authentication

  @spec logged_in?(Authentication.t()) :: boolean
  def logged_in?(nil), do: false
  def logged_in?(_auth), do: true

  @spec has_role?(Authentication.t(), Types.role()) :: boolean
  def has_role?(nil, _role), do: false
  def has_role?(auth, role), do: Authentication.has_role?(auth, role)

  @spec username(Authentication.t()) :: String.t()
  def username(auth), do: Authentication.username(auth)

  @spec current_session?(Authentication.t(), UserSession.t()) :: boolean
  defdelegate current_session?(auth, session), to: Authentication
end
