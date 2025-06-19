defmodule ArchiDep.Servers do
  use ArchiDep, :context

  @behaviour ArchiDep.Servers.Behaviour

  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Types

  @implementation Application.compile_env!(:archidep, __MODULE__)

  @spec validate_server(Authentication.t(), Types.create_server_data()) :: Changeset.t()
  defdelegate validate_server(auth, data), to: @implementation

  @spec create_server(Authentication.t(), Types.create_server_data()) ::
          {:ok, Server.t()} | {:error, Changeset.t()}
  defdelegate create_server(auth, data), to: @implementation

  @spec list_my_servers(Authentication.t()) :: list(Server.t())
  defdelegate list_my_servers(auth), to: @implementation

  @spec fetch_server(Authentication.t(), UUID.t()) ::
          {:ok, Server.t()} | {:error, :server_not_found}
  defdelegate fetch_server(auth, id), to: @implementation

  @spec notify_server_up(UUID.t(), binary(), binary()) :: :ok | {:error, :server_not_found}
  defdelegate notify_server_up(server_id, nonce, signature), to: @implementation

  @spec validate_existing_server(Authentication.t(), UUID.t(), Types.update_server_data()) ::
          {:ok, Changeset.t()} | {:error, :server_not_found}
  defdelegate validate_existing_server(auth, id, data), to: @implementation

  @spec update_server(Authentication.t(), UUID.t(), Types.update_server_data()) ::
          {:ok, Server.t()} | {:error, Changeset.t()} | {:error, :server_not_found}
  defdelegate update_server(auth, id, data), to: @implementation
end
