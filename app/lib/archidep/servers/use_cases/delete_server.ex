defmodule ArchiDep.Servers.UseCases.DeleteServer do
  @moduledoc """
  Use case for deleting servers.

  Note that this use case exposes two public functions because operations that
  affect a server are serialized through the server manager. The first function
  sends the modification request to the server manager, which then calls the
  second function to perform the actual changes in the database. This gives the
  server manager a chance to refuse the operation if the server is busy.
  """

  use ArchiDep, :use_case

  alias ArchiDep.Servers.Events.ServerDeleted
  alias ArchiDep.Servers.Policy
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerOwner
  alias ArchiDep.Servers.ServerTracking.ServerManager
  alias ArchiDep.Servers.ServerTracking.ServersOrchestrator

  @spec delete_server(Authentication.t(), UUID.t()) ::
          :ok | {:error, :server_busy} | {:error, :server_not_found}
  def delete_server(auth, server_id) when is_binary(server_id) do
    with :ok <- validate_uuid(server_id, :server_not_found),
         {:ok, server} <- Server.fetch_server(server_id),
         :ok <- authorize(auth, Policy, :servers, :delete_server, server) do
      :ok = ServersOrchestrator.ensure_started(server)
      ServerManager.delete_server(server, auth)
    else
      {:error, {:access_denied, :servers, :delete_server}} ->
        {:error, :server_not_found}
    end
  end

  @spec delete_server(Authentication.t(), Server.t()) :: :ok
  def delete_server(auth, server) when is_struct(server, Server) do
    now = DateTime.utc_now()

    {:ok, fresh_server_owner} = ServerOwner.fetch_server_owner(server.owner_id)

    case Multi.new()
         |> Multi.delete(:server, server)
         |> Multi.delete(:expected_properties, server.expected_properties)
         # Note: make sure to decrease the active server count before decreasing
         # the server count, or the database constraint checking the consistency
         # of the two will complain.
         |> Multi.merge(&decrease_active_server_count(fresh_server_owner, &1.server))
         |> Multi.update(
           :server_limit,
           &ServerOwner.update_server_count(
             Map.get(&1, :active_server_limit, fresh_server_owner),
             -1
           )
         )
         |> Multi.insert(:stored_event, &server_deleted(auth, &1.server, now))
         |> Repo.transaction() do
      {:ok, _changes} ->
        :ok = PubSub.publish_server_deleted(server)
        :ok
    end
  end

  defp decrease_active_server_count(owner, %Server{active: true}),
    do:
      Multi.update(
        Multi.new(),
        :active_server_limit,
        ServerOwner.update_active_server_count(owner, -1)
      )

  defp decrease_active_server_count(_owner, _server), do: Multi.new()

  defp server_deleted(auth, server, now),
    do:
      server
      |> ServerDeleted.new()
      |> new_event(auth, occurred_at: now)
      |> add_to_stream(server)
      |> initiated_by(auth)
end
