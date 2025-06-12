defmodule ArchiDep.Servers.UpdateServer do
  use ArchiDep, :use_case

  alias ArchiDep.Servers.Events.ServerUpdated
  alias ArchiDep.Servers.Policy
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Types

  @spec validate_existing_server(Authentication.t(), UUID.t(), Types.server_data()) ::
          {:ok, Changeset.t()} | {:error, :server_not_found}
  def validate_existing_server(auth, id, data) do
    with {:ok, server} <- Server.fetch_server(id) do
      authorize!(auth, Policy, :servers, :validate_existing_server, server)
      {:ok, Server.update(server, data)}
    end
  end

  @spec update_server(Authentication.t(), UUID.t(), Types.server_data()) ::
          {:ok, Server.t()} | {:error, Changeset.t()} | {:error, :server_not_found}
  def update_server(auth, id, data) do
    with {:ok, server} <- Server.fetch_server(id) do
      authorize!(auth, Policy, :servers, :update_server, server)

      user = Authentication.fetch_user_account(auth)

      case Multi.new()
           |> Multi.update(:server, Server.update(server, data))
           |> Multi.insert(:stored_event, fn %{server: server} ->
             ServerUpdated.new(server)
             |> new_event(auth, occurred_at: server.updated_at)
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
end
