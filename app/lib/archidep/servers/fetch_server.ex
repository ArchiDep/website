defmodule ArchiDep.Servers.FetchServer do
  use ArchiDep, :use_case

  alias ArchiDep.Servers.Policy
  alias ArchiDep.Servers.Schemas.Server

  @spec fetch_server(Authentication.t(), UUID.t()) ::
          {:ok, Server.t()} | {:error, :server_not_found}
  def fetch_server(auth, id) do
    with {:ok, server} <- Server.fetch_server(id),
         :ok <- authorize(auth, Policy, :servers, :fetch_server, server) do
      {:ok, server}
    else
      {:error, {:access_denied, :servers, :fetch_server}} ->
        {:error, :server_not_found}
    end
  end
end
