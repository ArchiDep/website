defmodule ArchiDepWeb.Servers.ServerCallbacksController do
  use ArchiDepWeb, :controller

  @spec server_up(Conn.t(), map) :: Conn.t()
  def server_up(conn, %{"server_id" => server_id}) do
    IO.puts("Server up: #{server_id}")

    send_resp(conn, 200, "Server up")
  end
end
