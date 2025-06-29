defmodule ArchiDepWeb.Profile.CurrentSessionsLive do
  @moduledoc """
  A component that lists all active sessions of the currently authenticated
  user.
  """

  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Helpers.UserAgentFormatHelpers
  alias ArchiDep.Accounts
  alias ArchiDep.Accounts.Schemas.UserSession
  alias ArchiDepWeb.LiveAuth

  @id "current-sessions"
  @two_days_in_seconds 2 * 24 * 60 * 60

  @doc """
  Returns the ID of the component.
  """
  @spec id() :: String.t()
  def id, do: @id

  @doc """
  Returns the expiration date of the specified session.
  """
  @spec expires_at(UserSession.t()) :: DateTime.t()
  defdelegate expires_at(session), to: UserSession

  @doc """
  Indicates whether the specified session has expired.
  """
  @spec expired?(UserSession.t()) :: boolean
  def expired?(session),
    do: session |> expires_at() |> DateTime.diff(DateTime.utc_now()) < 0

  @doc """
  Indicates whether the specified session is about to expire and should be
  highlighted in the UI.
  """
  @spec expires_soon?(UserSession.t()) :: boolean
  def expires_soon?(session),
    do: session |> expires_at() |> DateTime.diff(DateTime.utc_now()) < @two_days_in_seconds

  @doc """
  Deletes the specified session.
  """
  @spec delete_session(UserSession.t()) :: js
  def delete_session(%UserSession{id: id}),
    do: JS.push("delete_session", value: %{"session_id" => id})

  @impl LiveComponent
  def mount(socket) do
    ok(socket)
  end

  @impl LiveComponent
  def update(assigns, socket) do
    socket
    |> assign(active_sessions: fetch_active_sessions(assigns.auth), auth: assigns.auth)
    |> ok()
  end

  @impl LiveComponent

  def handle_event("delete_session", %{"session_id" => session_id}, socket) do
    case LiveAuth.delete_session(socket, session_id) do
      {:ok, _deleted_session} ->
        socket
        |> remove_session(session_id)
        |> send_notification(Message.new(:success, gettext("Deleted session")))
        |> noreply()

      {:error, :session_not_found} ->
        send(self(), :session_to_delete_not_found)

        socket
        |> remove_session(session_id)
        |> noreply()
    end
  end

  defp fetch_active_sessions(auth), do: Accounts.fetch_active_sessions(auth)

  defp remove_session(socket, session_id),
    do:
      assign(socket,
        active_sessions:
          Enum.filter(socket.assigns.active_sessions, fn %{id: id} -> id != session_id end)
      )
end
