defmodule ArchiDepWeb.Servers.ServerCallbacksController do
  use ArchiDepWeb, :controller

  alias ArchiDep.Servers

  @spec server_up(Conn.t(), map) :: Conn.t()
  def server_up(conn, %{"server_id" => server_id, "nonce" => nonce, "signature" => signature})
      when is_binary(server_id) and is_binary(nonce) and is_binary(signature) do
    with true <- String.length(nonce) >= 64,
         {:ok, decoded_nonce} <- Base.decode64(nonce),
         :ok <- Servers.notify_server_up(server_id, decoded_nonce, signature) do
      send_resp(conn, 202, "")
    else
      {:error, :server_not_found} ->
        send_resp(conn, 401, "")
    end
  end

  @spec server_up(Conn.t(), map) :: Conn.t()
  def server_up(conn, _params) do
    send_resp(conn, 400, "")
  end
end
