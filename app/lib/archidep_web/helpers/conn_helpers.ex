defmodule ArchiDepWeb.Helpers.ConnHelpers do
  @moduledoc """
  Connection-related helper functions.
  """

  import Plug.Conn, only: [get_peer_data: 1, get_req_header: 2]
  alias Plug.Conn

  @doc """
  Extracts common metadata from a connection.
  """
  @spec conn_metadata(Conn.t()) :: map
  def conn_metadata(conn),
    do: %{
      client_ip_address: get_peer_data(conn).address,
      client_user_agent: conn |> get_req_header("user-agent") |> List.first()
    }
end
