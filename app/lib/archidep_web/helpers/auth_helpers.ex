defmodule ArchiDepWeb.Helpers.AuthHelpers do
  @moduledoc """
  Authentication-related helpers for the web application.
  """

  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Authentication

  @spec logged_in?(Authentication.t()) :: boolean
  def logged_in?(nil), do: false
  def logged_in?(_auth), do: true

  @spec username(Authentication.t()) :: String.t()
  def username(auth), do: Authentication.username(auth)

  @spec current_session?(Authentication.t(), UserSession.t()) :: boolean
  defdelegate current_session?(auth, session), to: Authentication
end
