defmodule ArchiDep.Servers.ContextImpl do
  use ArchiDep, :context

  alias ArchiDep.Servers.CreateServer
  alias ArchiDep.Servers.FetchServer
  alias ArchiDep.Servers.ListServers
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerCallbacks
  alias ArchiDep.Servers.Types
  alias ArchiDep.Servers.UpdateServer

  @spec validate_server(Authentication.t(), Types.create_server_data()) :: Changeset.t()
  defdelegate validate_server(auth, data), to: CreateServer

  @spec create_server(Authentication.t(), Types.create_server_data()) ::
          {:ok, Server.t()} | {:error, Changeset.t()}
  defdelegate create_server(auth, data), to: CreateServer

  @spec list_my_servers(Authentication.t()) :: list(Server.t())
  defdelegate list_my_servers(auth), to: ListServers

  @spec fetch_server(Authentication.t(), UUID.t()) ::
          {:ok, Server.t()} | {:error, :server_not_found}
  defdelegate fetch_server(auth, id), to: FetchServer

  @spec notify_server_up(UUID.t(), binary(), binary()) :: :ok | {:error, :server_not_found}
  defdelegate notify_server_up(server_id, nonce, signature), to: ServerCallbacks

  @spec validate_existing_server(Authentication.t(), UUID.t(), Types.update_server_data()) ::
          {:ok, Changeset.t()} | {:error, :server_not_found}
  defdelegate validate_existing_server(auth, id, data), to: UpdateServer

  @spec update_server(Authentication.t(), UUID.t(), Types.update_server_data()) ::
          {:ok, Server.t()} | {:error, Changeset.t()} | {:error, :server_not_found}
  defdelegate update_server(auth, id, data), to: UpdateServer
end
