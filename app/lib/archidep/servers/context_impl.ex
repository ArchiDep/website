defmodule ArchiDep.Servers.ContextImpl do
  use ArchiDep, :context

  alias ArchiDep.Servers.CreateServer
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Types

  @spec validate_server(Authentication.t(), Types.create_server_data()) :: Changeset.t()
  defdelegate validate_server(auth, data), to: CreateServer

  @spec create_server(Authentication.t(), Types.create_server_data()) ::
          {:ok, Server.t()} | {:error, Changeset.t()}
  defdelegate create_server(auth, data), to: CreateServer
end
