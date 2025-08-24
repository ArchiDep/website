defmodule ArchiDepWeb.Helpers.AuthHelpers do
  @moduledoc """
  Authentication-related helpers for the web application.
  """

  alias ArchiDep.Authentication

  @spec logged_in?(Authentication.t()) :: boolean()
  def logged_in?(nil), do: false
  def logged_in?(_auth), do: true

  @spec root?(Authentication.t()) :: boolean()
  def root?(nil), do: false
  def root?(auth), do: Authentication.root?(auth)

  @spec can_impersonate?(Authentication.t(), struct()) :: boolean()
  def can_impersonate?(nil, _user_account), do: false

  def can_impersonate?(
        %Authentication{
          principal_id: principal_id,
          impersonated_id: impersonated_id
        },
        %{id: user_account_id}
      ),
      do: impersonated_id == nil and user_account_id != principal_id

  @spec impersonating?(Authentication.t()) :: boolean()
  def impersonating?(nil), do: false

  def impersonating?(%Authentication{impersonated_id: nil}),
    do: false

  def impersonating?(_auth), do: true

  @spec username(Authentication.t()) :: String.t()
  defdelegate username(auth), to: Authentication
end
