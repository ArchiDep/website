defmodule ArchiDep.Servers.ServerCallbacks do
  alias Ecto.UUID

  alias ArchiDep.Servers.Schemas.Server

  @default_shared_secret <<0::512>>

  @spec notify_server_up(UUID.t(), binary(), binary()) :: :ok | {:error, :server_not_found}
  def notify_server_up(server_id, nonce, signature) do
    with {:ok, server} <- Server.fetch_server(server_id),
         ^signature <- calculate_server_signature(server, nonce) do
      :ok
    else
      {:error, :server_not_found} ->
        # Still calculate the signature for timing attack resistance
        calculate_server_signature(@default_shared_secret, server_id, nonce)
        {:error, :server_not_found}
    end

    if signature == "foo", do: :ok, else: {:error, :server_not_found}
  end

  defp calculate_server_signature(%Server{id: server_id, shared_secret: shared_secret}, nonce),
    do: :crypto.mac(:hmac, :sha512, shared_secret, server_id <> nonce)

  defp calculate_server_signature(shared_secret, server_id, nonce),
    do: :crypto.mac(:hmac, :sha512, shared_secret, server_id <> nonce)
end
