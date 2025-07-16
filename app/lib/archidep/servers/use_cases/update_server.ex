defmodule ArchiDep.Servers.UseCases.UpdateServer do
  use ArchiDep, :use_case

  alias ArchiDep.Servers.Events.ServerUpdated
  alias ArchiDep.Servers.Policy
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Servers.ServerManager
  alias ArchiDep.Servers.ServerOrchestrator
  alias ArchiDep.Servers.Types

  @spec validate_existing_server(Authentication.t(), UUID.t(), Types.update_server_data()) ::
          {:ok, Changeset.t()} | {:error, :server_not_found}
  def validate_existing_server(auth, id, data) do
    with :ok <- validate_uuid(id, :server_not_found),
         {:ok, server} <- Server.fetch_server(id) do
      authorize!(auth, Policy, :servers, :validate_existing_server, server)

      owner = ServerOwner.fetch_authenticated(auth)

      {:ok, update_server_changeset(auth, server, data, owner)}
    end
  end

  @spec update_server(Authentication.t(), UUID.t(), Types.update_server_data()) ::
          {:ok, Server.t()}
          | {:error, Changeset.t()}
          | {:error, :server_busy}
          | {:error, :server_not_found}
  def update_server(auth, server_id, data) when is_binary(server_id) do
    with :ok <- validate_uuid(server_id, :server_not_found),
         {:ok, server} <- Server.fetch_server(server_id),
         :ok <- authorize(auth, Policy, :servers, :update_server, server) do
      :ok = ServerOrchestrator.ensure_started(server)
      ServerManager.update_server(server, auth, data)
    else
      {:error, {:access_denied, :servers, :update_server}} ->
        {:error, :server_not_found}
    end
  end

  @spec update_server(Authentication.t(), Server.t(), Types.update_server_data()) ::
          {:ok, Server.t()} | {:error, Changeset.t()}
  def update_server(auth, server, data) when is_struct(server, Server) do
    owner = ServerOwner.fetch_authenticated(auth)

    case Multi.new()
         |> Multi.update(:server, update_server_changeset(auth, server, data, owner))
         |> Multi.merge(&update_active_server_count(owner, server.active, &1.server))
         |> Multi.insert(:stored_event, &server_updated(auth, &1.server))
         |> Repo.transaction() do
      {:ok, %{server: updated_server}} ->
        :ok = PubSub.publish_server_updated(updated_server)
        {:ok, updated_server}

      {:error, :server, changeset, _} ->
        {:error, changeset}
    end
  end

  defp update_server_changeset(auth, server, data, owner) do
    if has_role?(auth, :root) do
      Server.update(server, data)
    else
      Server.update_group_member_server(server, data, owner)
    end
  end

  defp update_active_server_count(owner, was_active, %Server{active: active})
       when active != was_active,
       do:
         Multi.update(
           Multi.new(),
           :server_limit,
           ServerOwner.update_active_server_count(owner, if(active, do: 1, else: -1))
         )

  defp update_active_server_count(_owner, _was_active, _server), do: Multi.new()

  defp server_updated(auth, server),
    do:
      ServerUpdated.new(server)
      |> new_event(auth, occurred_at: server.updated_at)
      |> add_to_stream(server)
      |> initiated_by(auth)
end
