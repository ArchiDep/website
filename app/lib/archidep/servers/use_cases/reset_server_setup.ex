defmodule ArchiDep.Servers.UseCases.ResetServerSetup do
  @moduledoc """
  Use case for resetting a server's setup, so that the application connects to
  it with its initial username and sets it up again, as it would a new server. A
  teacher does this when a student replaced their machine with a new one but
  kept the server record, editing its IP address and host keys: the new machine
  does not have the application user yet, so the application cannot log in as
  that user.

  Like `ArchiDep.Servers.UseCases.UpdateServer`, this use case exposes two
  public functions because operations that affect a server are serialized
  through the server manager. The first function sends the request to the server
  manager, which then calls the second function to perform the actual changes in
  the database. This gives the server manager a chance to refuse the operation
  if the server is busy, and to reconnect with the initial username once the
  setup has been reset.
  """

  use ArchiDep, :use_case

  alias ArchiDep.Clock
  alias ArchiDep.Servers.Events.ServerSetupReset
  alias ArchiDep.Servers.Policy
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerTracking.ServerManagerClient
  alias ArchiDep.Servers.ServerTracking.ServersOrchestratorClient

  @spec reset_server_setup(Authentication.t(), UUID.t()) ::
          :ok | {:error, :server_busy} | {:error, :server_not_found}
  def reset_server_setup(auth, server_id) when is_binary(server_id) do
    with :ok <- validate_uuid(server_id, :server_not_found),
         {:ok, server} <- Server.fetch_server(server_id),
         :ok <- authorize(auth, Policy, :servers, :reset_server_setup, server) do
      :ok = ServersOrchestratorClient.ensure_started(server)
      ServerManagerClient.reset_server_setup(server, auth)
    else
      {:error, {:access_denied, :servers, :reset_server_setup}} ->
        {:error, :server_not_found}

      {:error, :server_not_found} ->
        {:error, :server_not_found}
    end
  end

  @spec reset_server_setup(Authentication.t(), Server.t()) ::
          {:ok, Server.t(), EventReference.t()}
  def reset_server_setup(auth, %Server{set_up_at: %DateTime{}} = server) do
    now = Clock.now()

    case Multi.new()
         |> Multi.update(:server, Server.reset_setup(server, now))
         |> Multi.insert(:stored_event, &server_setup_reset(auth, &1.server))
         |> Repo.transaction() do
      {:ok, %{server: updated_server, stored_event: event}} ->
        reference = StoredEvent.to_reference(event)
        :ok = PubSub.publish_server_updated(event.data, reference)
        {:ok, updated_server, reference}
    end
  end

  defp server_setup_reset(auth, server),
    do:
      server
      |> ServerSetupReset.new()
      |> new_event(auth, occurred_at: server.updated_at)
      |> add_to_stream(server)
      |> initiated_by(auth)
end
