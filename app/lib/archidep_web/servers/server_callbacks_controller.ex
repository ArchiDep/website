defmodule ArchiDepWeb.Servers.ServerCallbacksController do
  use ArchiDepWeb, :controller

  alias ArchiDep.Servers

  @spec server_up(Conn.t(), map) :: Conn.t()
  def server_up(conn, %{"server_id" => server_id}) do
    with {:ok, token} <- get_bearer_token(conn),
         :ok <- Servers.notify_server_up(server_id, token) do
      send_resp(conn, 202, "")
    else
      :error ->
        send_resp(conn, 401, "")

      {:error, :server_not_found} ->
        send_resp(conn, 401, "")
    end
  end

  defp get_bearer_token(conn) when is_struct(conn, Conn),
    do: conn |> get_req_header("authorization") |> get_bearer_token()

  defp get_bearer_token([]), do: :error

  defp get_bearer_token([authorization]) when is_binary(authorization),
    do: get_bearer_token(authorization)

  defp get_bearer_token([authorization | _rest]) when is_binary(authorization), do: :error
  defp get_bearer_token("Bearer " <> token), do: {:ok, token}
  defp get_bearer_token(authorization) when is_binary(authorization), do: :error
end
