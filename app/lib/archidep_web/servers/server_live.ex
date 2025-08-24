defmodule ArchiDepWeb.Servers.ServerLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.LiveViewHelpers
  import ArchiDepWeb.Servers.ServerComponents
  alias ArchiDep.Servers
  alias ArchiDep.Servers.PubSub
  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDep.Servers.ServerTracking.ServerTracker
  alias ArchiDepWeb.Servers.DeleteServerDialogLive
  alias ArchiDepWeb.Servers.EditServerDialogLive

  @impl LiveView
  def mount(%{"id" => id}, _session, socket) do
    auth = socket.assigns.auth

    case Servers.fetch_server(auth, id) do
      {:ok, server} ->
        if connected?(socket) do
          set_process_label(__MODULE__, auth, server)
          # TODO: add watch_server in context
          :ok = PubSub.subscribe_server(server.id)
          {:ok, _pid} = ServerTracker.start_link(server)
        end

        socket
        |> assign(
          page_title:
            "#{gettext("ArchiDep")} > #{gettext("Servers")} > #{Server.name_or_default(server)}",
          server: server,
          state: ServerTracker.get_current_server_state(server)
        )
        |> ok()

      {:error, :server_not_found} ->
        socket
        |> put_notification(Message.new(:error, gettext("Server not found")))
        |> push_navigate(to: ~p"/app")
        |> ok()
    end
  end

  @impl LiveView
  def handle_params(_params, _url, socket), do: noreply(socket)

  @impl LiveView
  def handle_event(
        "retry_connecting",
        %{"server_id" => server_id},
        %Socket{assigns: %{auth: auth, server: %Server{id: server_id}}} = socket
      ) do
    :ok = Servers.retry_connecting(auth, server_id)
    noreply(socket)
  end

  @impl LiveView
  def handle_event(
        "retry_operation",
        %{"server_id" => server_id, "operation" => "ansible-playbook", "playbook" => playbook},
        %Socket{assigns: %{auth: auth, server: %Server{id: server_id}}} = socket
      ) do
    case Servers.retry_ansible_playbook(auth, server_id, playbook) do
      :ok ->
        noreply(socket)

      {:error, :server_not_connected} ->
        socket
        |> put_notification(
          Message.new(
            :error,
            gettext("Cannot retry because the server is not connected.")
          )
        )
        |> noreply()

      {:error, :server_busy} ->
        socket
        |> put_notification(
          Message.new(
            :error,
            gettext("Cannot retry because the server is busy. Please try again later.")
          )
        )
        |> noreply()
    end
  end

  @impl LiveView
  def handle_event(
        "retry_operation",
        %{"server_id" => server_id, "operation" => "check-open-ports"},
        %Socket{assigns: %{auth: auth, server: %Server{id: server_id}}} = socket
      ) do
    case Servers.retry_checking_open_ports(auth, server_id) do
      :ok ->
        noreply(socket)

      {:error, :server_not_connected} ->
        socket
        |> put_notification(
          Message.new(
            :error,
            gettext("Cannot retry because the server is not connected.")
          )
        )
        |> noreply()

      {:error, :server_busy} ->
        socket
        |> put_notification(
          Message.new(
            :error,
            gettext("Cannot retry because the server is busy. Please try again later.")
          )
        )
        |> noreply()
    end
  end

  @impl LiveView
  def handle_info(
        {:server_state, server_id, new_server_state},
        %Socket{assigns: %{server: %Server{id: server_id}}} = socket
      ),
      do:
        socket
        |> assign(state: new_server_state)
        |> noreply()

  @impl LiveView
  def handle_info({:server_updated, server}, socket),
    do: socket |> assign(server: server) |> noreply()

  @impl LiveView
  def handle_info(
        {:server_deleted, %Server{id: server_id} = deleted_server},
        %{assigns: %{server: %Server{id: server_id}}} = socket
      ),
      do:
        socket
        |> put_notification(
          Message.new(
            :success,
            gettext("Deleted server {server}", server: Server.name_or_default(deleted_server))
          )
        )
        |> push_navigate(to: ~p"/app")
        |> noreply()
end
