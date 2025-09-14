defmodule ArchiDepWeb.Servers.ServerLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.LiveViewHelpers
  import ArchiDepWeb.Servers.ServerComponents
  import ArchiDepWeb.Servers.ServerRetryHandlers
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
          page_title: Server.name_or_default(server),
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
  def handle_params(_params, url, socket) do
    uri = URI.parse(url)

    socket
    |> assign(admin_ui: String.starts_with?(uri.path, "/admin"))
    |> noreply()
  end

  @impl LiveView
  def handle_event(
        "retry_connecting",
        %{"server_id" => server_id},
        %Socket{assigns: %{server: %Server{id: server_id}}} = socket
      ),
      do: handle_retry_connecting_event(socket, server_id)

  @impl LiveView
  def handle_event(
        "retry_operation",
        %{"server_id" => server_id, "operation" => "ansible-playbook", "playbook" => playbook},
        %Socket{assigns: %{server: %Server{id: server_id}}} = socket
      ),
      do: handle_retry_ansible_playbook_event(socket, server_id, playbook)

  @impl LiveView
  def handle_event(
        "retry_operation",
        %{"server_id" => server_id, "operation" => "check-open-ports"},
        %Socket{assigns: %{server: %Server{id: server_id}}} = socket
      ),
      do: handle_retry_checking_open_ports_event(socket, server_id)

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
        |> push_navigate(to: redirect_after_deleted(socket))
        |> noreply()

  defp redirect_after_deleted(%Socket{assigns: %{admin_ui: true}}), do: ~p"/admin"
  defp redirect_after_deleted(_socket), do: ~p"/app"
end
