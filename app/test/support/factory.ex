defmodule ArchiDep.Support.Factory do
  @moduledoc """
  Test fixtures for general data.
  """

  use ArchiDep.Support, :factory

  alias ArchiDep.Authentication
  alias ArchiDep.ClientMetadata
  alias ArchiDep.Support.AccountsFactory
  alias ArchiDep.Support.NetFactory

  @sample_user_agents [
    "Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:47.0) Gecko/20100101 Firefox/47.3",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X x.y; rv:42.0) Gecko/20100101 Firefox/43.4",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36",
    "Mozilla/5.0 (iPad; U; CPU OS 3_2_1 like Mac OS X; en-us) AppleWebKit/531.21.10 (KHTML, like Gecko) Mobile/7B405",
    "Googlebot/2.1 (+http://www.google.com/bot.html)"
  ]

  @spec authentication_factory(map()) :: Authentication.t()
  def authentication_factory(attrs!) do
    {principal_id, attrs!} = Map.pop_lazy(attrs!, :principal_id, &UUID.generate/0)

    {username, attrs!} =
      Map.pop_lazy(attrs!, :username, fn ->
        sequence(:authentication_username, &"auth-user-#{&1}")
      end)

    {roles, attrs!} = Map.pop_lazy(attrs!, :roles, &AccountsFactory.role/0)
    {session_id, attrs!} = Map.pop_lazy(attrs!, :session_id, &UUID.generate/0)

    {session_token, attrs!} =
      Map.pop_lazy(attrs!, :session_token, fn ->
        sequence(:authentication_session_token, &"auth-session-token-#{&1}")
      end)

    {session_expires_at, attrs!} =
      Map.pop_lazy(attrs!, :session_expires_at, fn -> Faker.DateTime.forward(60) end)

    {impersonated_id, attrs!} =
      Map.pop_lazy(attrs!, :impersonated_id, optionally(&UUID.generate/0))

    [] = Map.keys(attrs!)

    %Authentication{
      principal_id: principal_id,
      username: username,
      roles: roles,
      session_id: session_id,
      session_token: session_token,
      session_expires_at: session_expires_at,
      impersonated_id: impersonated_id
    }
  end

  @spec client_metadata_factory(map()) :: ClientMetadata.t()
  def client_metadata_factory(attrs!) do
    {ip_address, attrs!} = Map.pop_lazy(attrs!, :ip_address, optionally(&NetFactory.ip_address/0))
    {user_agent, attrs!} = Map.pop_lazy(attrs!, :user_agent, optionally(&user_agent/0))
    [] = Map.keys(attrs!)

    ClientMetadata.new(ip_address, user_agent)
  end

  @spec user_agent() :: String.t()
  def user_agent, do: Enum.random(@sample_user_agents)
end
