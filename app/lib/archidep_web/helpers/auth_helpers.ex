defmodule ArchiDepWeb.Helpers.AuthHelpers do
  @moduledoc """
  Authentication-related helpers for the web application.
  """

  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.Authentication

  @doc """
  Returns the currently authenticated user.

  ## Examples

      iex> ArchiDepWeb.AuthHelpers.logged_in?(nil)
      false

      iex> import ArchiDepTesting.Factory
      iex> :user_authentication |> build() |> ArchiDepWeb.AuthHelpers.logged_in?()
      true
  """
  @spec logged_in?(Authentication.t()) :: boolean
  def logged_in?(nil), do: false
  def logged_in?(_auth), do: true

  @doc """
  Returns the username of the currently authenticated user.
  """
  @spec current_username(Authentication.t()) :: String.t()
  defdelegate current_username(auth), to: Authentication

  @spec current_session?(Authentication.t(), UserSession.t()) :: boolean
  defdelegate current_session?(auth, session), to: Authentication
end
