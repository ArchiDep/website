defmodule ArchiDepWeb.LiveAuth do
  @moduledoc """
  Helpers to handle live view authentication based on session cookies.
  """

  use ArchiDepWeb, :verified_routes
  use Gettext, backend: ArchiDepWeb.Gettext
  import ArchiDep.Helpers.PipeHelpers
  import ArchiDepWeb.Helpers.AuthHelpers
  import Flashy
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView
  alias ArchiDep.Accounts
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDep.ClientMetadata
  alias ArchiDep.Course
  alias ArchiDepWeb.ClientSessionData
  alias ArchiDepWeb.Components.Notifications.Message
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
  def on_mount(:default, _params, session, socket),
    do:
      socket
      |> get_client_metadata()
      |> get_token_from_session(session)
      |> authenticate_with_token()
      |> require_authenticated_user()

  defp get_client_metadata(socket),
    do:
      socket
      |> assign(:peer_data, get_connect_info(socket, :peer_data))
      |> assign(:user_agent, get_connect_info(socket, :user_agent))

  defp get_token_from_session(socket, session),
    do: assign(socket, :session_token, Map.get(session, "session_token"))

  defp authenticate_with_token(%Socket{assigns: %{session_token: token}} = socket)
       when is_binary(token) do
    case Accounts.validate_session_token(token, socket_metadata(socket)) do
      {:ok, auth} ->
        student =
          if root?(auth) do
            nil
          else
            case Course.fetch_authenticated_student(auth) do
              {:ok, student} -> student
              {:error, _reason} -> nil
            end
          end

        socket
        |> assign(:auth, auth)
        |> push_event("authenticated", ClientSessionData.new(auth, student))

      {:error, :session_not_found} ->
        socket
    end
  end

  defp authenticate_with_token(socket), do: socket

  defp require_authenticated_user(socket) do
    if socket.assigns[:auth] do
      {:cont, socket}
    else
      query_params =
        case Map.get(socket.private.connect_info, :request_path) do
          current_path when is_binary(current_path) -> %{to: current_path}
          nil -> %{}
        end

      socket
      |> put_notification(Message.new(:error, gettext("You must log in to access this page.")))
      |> redirect(to: ~p"/login?#{query_params}")
      |> pair(:halt)
    end
  end

  defp socket_metadata(%Socket{assigns: %{peer_data: peer_data} = assigns}),
    do: ClientMetadata.new(peer_data.address, Map.get(assigns, :user_agent))
end
