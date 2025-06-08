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
end
