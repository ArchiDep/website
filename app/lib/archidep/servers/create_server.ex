defmodule ArchiDep.Servers.CreateServer do
  use ArchiDep, :use_case

  alias ArchiDep.Servers.Events.ServerCreated
  alias ArchiDep.Servers.Policy
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Types

  @spec validate_server(Authentication.t(), Types.create_server_data()) :: Changeset.t()
  def validate_server(auth, data) do
    authorize!(auth, Policy, :students, :validate_server, nil)
    Server.new(data)
  end

  @spec create_server(Authentication.t(), Types.create_server_data()) ::
          {:ok, Server.t()} | {:error, Changeset.t()}
  def create_server(auth, data) do
    authorize!(auth, Policy, :students, :create_server, nil)

    user = Authentication.fetch_user_account(auth)

    case Multi.new()
         |> Multi.insert(:server, Server.new(data))
         |> Multi.insert(:stored_event, fn %{server: server} ->
           ServerCreated.new(server)
           |> new_event(auth, occurred_at: server.created_at)
           |> add_to_stream(server)
           |> initiated_by(user)
         end)
         |> Repo.transaction() do
      {:ok, %{server: server}} ->
        {:ok, server}

      {:error, :server, changeset, _} ->
        {:error, changeset}
    end
  end
end
