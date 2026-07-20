defmodule ArchiDepWeb.Servers.ServerLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.LiveViewHelpers
  import ArchiDepWeb.Servers.ServerComponents
  import ArchiDepWeb.Servers.ServerHelpComponent
  import ArchiDepWeb.Servers.ServerRetryHandlers
  alias ArchiDep.Servers
  alias ArchiDep.Servers.Events.ServerDeleted
  alias ArchiDep.Servers.Schemas.ServerRealTimeState
  alias ArchiDep.Servers.ServerTracking.ServerTrackerClient
  alias ArchiDep.Servers.ServerView
  alias ArchiDepWeb.LiveRefresh
  alias ArchiDepWeb.Servers.DeleteServerDialogLive
  alias ArchiDepWeb.Servers.EditServerDialogLive

  @impl LiveView
  def mount(%{"id" => id}, _session, socket) do
    auth = socket.assigns.auth

    case Servers.fetch_server(auth, id) do
      {:ok, server} ->
        if connected?(socket) do
          set_process_label(__MODULE__, auth, server)
          :ok = Servers.subscribe_server(server)
          {:ok, _pid} = ServerTrackerClient.start_link(server)
        end

        socket
        |> assign(
          page_title: ServerView.name_or_default(server),
          server: server,
          state: ServerTrackerClient.get_current_server_state(server.id)
        )
        |> attach_server_refresh()
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
        %Socket{assigns: %{server: %ServerView{id: server_id}}} = socket
      ),
      do: handle_retry_connecting_event(socket, server_id)

  @impl LiveView
  def handle_event(
        "retry_operation",
        %{"server_id" => server_id, "operation" => "ansible-playbook", "playbook" => playbook},
        %Socket{assigns: %{server: %ServerView{id: server_id}}} = socket
      ),
      do: handle_retry_ansible_playbook_event(socket, server_id, playbook)

  @impl LiveView
  def handle_event(
        "retry_operation",
        %{"server_id" => server_id, "operation" => "check-open-ports"},
        %Socket{assigns: %{server: %ServerView{id: server_id}}} = socket
      ),
      do: handle_retry_checking_open_ports_event(socket, server_id)

  @impl LiveView
  def handle_info(
        {:server_state, server_id, new_server_state},
        %Socket{assigns: %{server: %ServerView{id: server_id}}} = socket
      ),
      do:
        socket
        |> assign(state: new_server_state)
        |> noreply()

  @impl LiveView
  def handle_info(
        {:server_deleted, %ServerDeleted{id: server_id} = deleted_server, _reference},
        %{assigns: %{server: %ServerView{id: server_id}}} = socket
      ),
      do:
        socket
        |> put_notification(
          Message.new(
            :success,
            gettext("Deleted server {server}",
              server: deleted_server.name || deleted_server.ip_address
            )
          )
        )
        |> push_navigate(to: redirect_after_deleted(socket))
        |> noreply()

  defp redirect_after_deleted(%Socket{assigns: %{admin_ui: true}}), do: ~p"/admin"
  defp redirect_after_deleted(_socket), do: ~p"/app"

  # On connected mount the `:server` read-model is kept current through the
  # Servers boundary. The hook halts `:server_updated` broadcasts and lets the
  # tracker's `:server_state` messages and the `:server_deleted` notice fall
  # through to this module's own `handle_info/2` clauses.
  defp attach_server_refresh(socket) do
    if connected?(socket) do
      LiveRefresh.attach(socket, :server, &Servers.refresh_server/2)
    else
      socket
    end
  end
end
