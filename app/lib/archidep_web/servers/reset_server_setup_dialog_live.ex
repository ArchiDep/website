defmodule ArchiDepWeb.Servers.ResetServerSetupDialogLive do
  @moduledoc """
  Confirmation dialog to reset the setup of a server, so that the application
  connects to it with its initial username and sets it up again (see
  `ArchiDep.Servers.UseCases.ResetServerSetup`).

  `ArchiDepWeb.Servers.ServerLive` offers it to root users only, and only for a
  server that has been set up. Besides the page's own button, the server card
  offers it on the application user's authentication failure, the usual sign
  that the server's machine was replaced by a new one.
  """

  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Helpers.DialogHelpers
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDep.Servers.ServerView

  @base_id "reset-server-setup-dialog"

  @spec id(ServerView.t()) :: String.t()
  def id(server), do: "#{@base_id}-#{server.id}"

  @spec open(ServerView.t()) :: js
  def open(server), do: server |> id() |> open_dialog()

  @spec close(ServerView.t()) :: js
  def close(server), do: server |> id() |> close_dialog()

  @impl LiveComponent
  def update(assigns, socket),
    do:
      socket
      |> assign(
        auth: assigns.auth,
        server: assigns.server,
        state: assigns.state
      )
      |> ok()

  @impl LiveComponent

  def handle_event("opened", _params, socket), do: {:noreply, socket}

  def handle_event("closed", _params, socket), do: {:noreply, socket}

  def handle_event("reset", _params, socket) do
    auth = socket.assigns.auth
    server = socket.assigns.server

    case Servers.reset_server_setup(auth, server.id) do
      :ok ->
        socket
        |> send_notification(
          Message.new(
            :success,
            gettext("Reset the setup of server {server}",
              server: ServerView.name_or_default(server)
            )
          )
        )
        |> push_event("execute-action", %{to: "##{id(server)}", action: "close"})
        |> noreply()

      {:error, :server_busy} ->
        socket
        |> send_notification(
          Message.new(
            :error,
            gettext("Cannot reset the setup because the server is busy. Please try again later.")
          )
        )
        |> noreply()

      {:error, :server_not_found} ->
        socket
        |> send_notification(
          Message.new(
            :error,
            gettext("Cannot reset the setup because the server no longer exists.")
          )
        )
        |> noreply()
    end
  end
end
