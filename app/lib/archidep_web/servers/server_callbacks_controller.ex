defmodule ArchiDepWeb.Servers.ServerCallbacksController do
  use ArchiDepWeb, :controller

  alias ArchiDep.Servers

  @spec server_up(Conn.t(), map) :: Conn.t()
  def server_up(conn, %{"server_id" => server_id}) do
    server_signature = get_server_signature(conn)

    with :ok <- Servers.notify_server_up(server_signature, server_id) do
      IO.puts("Server up: #{server_id}")

      send_resp(conn, 202, "")
    else
      {:error, :server_not_found} ->
        send_resp(conn, 401, "")
    end
  end

  defp get_server_signature(conn) when is_struct(conn, Conn),
    do:
      conn |> get_req_header("authorization") |> get_server_signature_from_authorization_header()

  defp get_server_signature_from_authorization_header(nil), do: ""

  defp get_server_signature_from_authorization_header(authorization) when is_list(authorization),
    do: authorization |> List.first() |> get_server_signature_from_authorization_header()

  defp get_server_signature_from_authorization_header(authorization)
       when is_binary(authorization),
       do: authorization |> String.split(" ") |> get_server_signature_from_authorization_token()

  defp get_server_signature_from_authorization_token(["ArchiDep-Server-Signature", token]),
    do: token

  defp get_server_signature_from_authorization_token(parts) when is_list(parts), do: ""
end
