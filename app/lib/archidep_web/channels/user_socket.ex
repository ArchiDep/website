defmodule ArchiDepWeb.Channels.UserSocket do
  @moduledoc """
  Persistent authenticated connection for user channels.
  """

  use Phoenix.Socket

  import ArchiDep.Helpers.PipeHelpers
  import ArchiDepWeb.Helpers.SocketHelpers
  import Plug.Conn, only: [send_resp: 3]
  alias ArchiDep.Accounts
  alias ArchiDep.ClientMetadata
  alias Phoenix.Socket
  alias Phoenix.Token
  alias Plug.Conn
  require Logger

  @five_minutes_in_seconds 300

  channel "me", ArchiDepWeb.Channels.UserChannel

  @impl Socket
  def connect(params, socket, connect_info) do
    with %{"token" => token} when is_binary(token) <- params,
         {:ok, session_id} <-
           Token.verify(socket, "user socket", token, max_age: @five_minutes_in_seconds),
         {:ok, auth} <- Accounts.validate_session_id(session_id, connect_metadata(connect_info)) do
      socket
      |> assign(:auth, auth)
      |> ok()
    else
      %{"token" => _invalid_token} ->
        Logger.warning("Failed to connect user socket due to malformed token")
        {:error, :invalid_token_type}

      %{} ->
        Logger.warning(
          "Failed to connect user socket due to invalid params (keys: #{inspect(Map.keys(params))})"
        )

        {:error, :missing_token}

      {:error, :invalid} ->
        Logger.warning("Failed to connect user socket due to invalid token")
        {:error, :unauthorized}

      {:error, :expired} ->
        Logger.warning("Failed to connect user socket due to expired token")
        {:error, :unauthorized}

      {:error, :session_not_found} ->
        {:error, :unauthorized}
    end
  end

  @impl Socket
  def id(%Socket{assigns: %{auth: auth}}), do: live_socket_id(auth)

  @doc """
  Handles errors that occur during the connection process. The configuration to
  use this function is defined in the endpoint configuration with the
  `error_handler` option of the `socket` call. (Documentation at
  https://hexdocs.pm/phoenix/Phoenix.Endpoint.html#socket/3-websocket-configuration.)
  """
  @spec handle_error(Conn.t(), term()) :: Conn.t()
  def handle_error(conn, {:error, :invalid_token_type}), do: send_resp(conn, 422, "")
  def handle_error(conn, {:error, :missing_token}), do: send_resp(conn, 422, "")
  def handle_error(conn, {:error, :unauthorized}), do: send_resp(conn, 401, "")

  defp connect_metadata(connect_info) do
    ip_address = get_in(connect_info, [:peer_data, :address])
    user_agent = Map.get(connect_info, :user_agent)
    ClientMetadata.new(ip_address, user_agent)
  end
end
