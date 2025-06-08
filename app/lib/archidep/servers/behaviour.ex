defmodule ArchiDep.Servers.Behaviour do
  use ArchiDep, :behaviour

  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Types

  @callback validate_server(Authentication.t(), Types.create_server_data()) :: Changeset.t()

  @callback create_server(Authentication.t(), Types.create_server_data()) ::
              {:ok, Server.t()} | {:error, Changeset.t()}

  @callback list_my_servers(Authentication.t()) :: list(Server.t())
end
