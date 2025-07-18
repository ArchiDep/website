defmodule ArchiDep.Servers.UseCases.ServerCallbacks do
  @moduledoc """
  Use cases to handle external callbacks by registered servers, such as
  notifying the system when a server comes online.
  """

  require Logger
  import ArchiDep.Helpers.DataHelpers
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.ServerTracking.ServerManager
  alias Ecto.UUID
  alias Phoenix.Token

  @one_year_in_seconds 60 * 60 * 24 * 365
  @default_secret_key :crypto.strong_rand_bytes(50)

  @spec notify_server_up(UUID.t(), String.t()) :: :ok | {:error, :server_not_found}
  def notify_server_up(server_id, token) when is_binary(server_id) and is_binary(token) do
    with :ok <- validate_uuid(server_id, :server_not_found),
         {:ok, server} <- Server.fetch_server(server_id),
         {:ok, ^server_id} <-
           Token.verify(server.secret_key, "server auth", token, max_age: @one_year_in_seconds) do
      :ok = ServerManager.notify_server_up(server_id)
    else
      {:error, :server_not_found} ->
        # Verify a token anyway against timing attacks
        Token.verify(@default_secret_key, "server auth", token, max_age: @one_year_in_seconds)
        {:error, :server_not_found}

      {:error, :expired} ->
        {:error, :server_not_found}

      {:error, :invalid} ->
        Logger.warning(
          "Received invalid server token #{inspect(token)} for server ID #{inspect(server_id)}"
        )

        {:error, :server_not_found}

      {:ok, other_server_id} ->
        Logger.warning(
          "Server ID mismatch: expected #{inspect(server_id)}, got ID #{inspect(other_server_id)} in signed token"
        )

        {:error, :server_not_found}
    end
  end
end
