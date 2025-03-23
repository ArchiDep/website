defmodule ArchiDepWeb.LiveAuth do
  @moduledoc """
  Helpers to handle live view authentication based on session cookies.
  """

  import ArchiDep.Helpers.PipeHelpers
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView
  alias ArchiDep.Accounts
  alias Phoenix.LiveView.Socket

  @doc """
  Deletes the specified session and logs out all associated live sockets.
  """
  @spec delete_session(Socket.t(), String.t()) ::
          {:ok, UserSession.t()} | {:error, :session_not_found}
  def delete_session(socket, id), do: Accounts.delete_session(socket.assigns.auth, id)

  @doc """
  Verifies that the user is logged in before mounting a live view.
  """
  @spec on_mount(atom, map, map, Socket.t()) :: {:cont, Socket.t()} | {:halt, Socket.t()}
  def on_mount(:default, _params, session, socket) do
    socket
    |> get_client_metadata()
    |> get_token_from_session(session)
    |> authenticate_with_token()
    |> require_authenticated_user()
  end

  defp get_client_metadata(socket) do
    socket
    |> assign(:peer_data, get_connect_info(socket, :peer_data))
    |> assign(:user_agent, get_connect_info(socket, :user_agent))
  end

  defp get_token_from_session(socket, session) do
    assign(socket, :session_token, Map.get(session, "session_token"))
  end

  defp authenticate_with_token(%Socket{assigns: %{session_token: token}} = socket)
       when is_binary(token) do
    case Accounts.validate_session(token, socket_metadata(socket)) do
      {:ok, auth} ->
        assign(socket, :auth, auth)

      {:error, :session_not_found} ->
        socket
    end
  end

  defp authenticate_with_token(socket), do: socket

  defp require_authenticated_user(socket) do
    if socket.assigns[:auth] do
      {:cont, socket}
    else
      socket
      |> put_flash(:error, "You must log in to access this page.")
      |> redirect(to: "/login")
      |> pair(:halt)
    end
  end

  defp socket_metadata(%Socket{assigns: %{peer_data: peer_data} = assigns}),
    do: %{
      client_ip_address: peer_data.address,
      client_user_agent: Map.get(assigns, :user_agent)
    }
end
