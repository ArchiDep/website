defmodule ArchiDep.Servers.UpdateServer do
  use ArchiDep, :use_case

  alias ArchiDep.Servers.Events.ServerUpdated
  alias ArchiDep.Servers.Policy
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerManager
  alias ArchiDep.Servers.ServerOrchestrator
  alias ArchiDep.Servers.Types

  @spec validate_existing_server(Authentication.t(), UUID.t(), Types.update_server_data()) ::
          {:ok, Changeset.t()} | {:error, :server_not_found}
  def validate_existing_server(auth, id, data) do
    with {:ok, server} <- Server.fetch_server(id) do
      authorize!(auth, Policy, :servers, :validate_existing_server, server)
      {:ok, Server.update(server, data)}
    end
  end

  @spec update_server(Authentication.t(), UUID.t(), Types.update_server_data()) ::
          {:ok, Server.t()} | {:error, Changeset.t()} | {:error, :server_not_found}
  def update_server(auth, server_id, data) when is_binary(server_id) do
    with {:ok, server} <- Server.fetch_server(server_id),
         :ok <- authorize(auth, Policy, :servers, :update_server, server) do
      :ok =
        case ServerOrchestrator.ensure_started(server) do
          {:ok, _pid} ->
            :ok

          {:error, {:already_started, _pid}} ->
            :ok
        end

      ServerManager.update_server(server, auth, data)
    else
      {:error, {:access_denied, :servers, :update_server}} ->
        {:error, :server_not_found}
    end
  end

  @spec update_server(Authentication.t(), Server.t(), Types.update_server_data()) ::
          {:ok, Server.t()} | {:error, Changeset.t()}
  def update_server(auth, server, data) when is_struct(server, Server) do
    case Multi.new()
         |> Multi.update(:server, Server.update(server, data))
         |> Multi.insert(:stored_event, fn %{server: server} ->
           ServerUpdated.new(server)
           |> new_event(auth, occurred_at: server.updated_at)
           |> add_to_stream(server)
           |> initiated_by(auth)
         end)
         |> Repo.transaction() do
      {:ok, %{server: updated_server}} ->
        :ok = PubSub.publish_server(updated_server)
        {:ok, updated_server}

      {:error, :server, changeset, _} ->
        {:error, changeset}
    end
  end
end
