defmodule ArchiDep.Servers.DeleteServer do
  use ArchiDep, :use_case

  alias ArchiDep.Servers.Events.ServerDeleted
  alias ArchiDep.Servers.Policy
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerManager
  alias ArchiDep.Servers.ServerOrchestrator

  @spec delete_server(Authentication.t(), UUID.t()) ::
          :ok | {:error, :server_busy} | {:error, :server_not_found}
  def delete_server(auth, server_id) when is_binary(server_id) do
    with {:ok, server} <- Server.fetch_server(server_id),
         :ok <- authorize(auth, Policy, :servers, :delete_server, server) do
      :ok =
        case ServerOrchestrator.ensure_started(server) do
          {:ok, _pid} ->
            :ok

          {:error, {:already_started, _pid}} ->
            :ok
        end

      ServerManager.delete_server(server, auth)
    else
      {:error, {:access_denied, :servers, :delete_server}} ->
        {:error, :server_not_found}
    end
  end

  @spec delete_server(Authentication.t(), Server.t()) :: :ok
  def delete_server(auth, server) when is_struct(server, Server) do
    now = DateTime.utc_now()

    case Multi.new()
         |> Multi.delete(:server, server)
         |> Multi.insert(:stored_event, fn %{server: server} ->
           ServerDeleted.new(server)
           |> new_event(auth, occurred_at: now)
           |> add_to_stream(server)
           |> initiated_by(auth)
         end)
         |> Repo.transaction() do
      {:ok, _} ->
        :ok
    end
  end
end
