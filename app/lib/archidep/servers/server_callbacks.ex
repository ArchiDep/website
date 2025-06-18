defmodule ArchiDep.Servers.ServerCallbacks do
  alias Ecto.UUID

  @spec notify_server_up(String.t(), UUID.t()) :: :ok | {:error, :server_not_found}
  def notify_server_up(signature, _server_id) do
    if signature == "foo", do: :ok, else: {:error, :server_not_found}
  end
end
