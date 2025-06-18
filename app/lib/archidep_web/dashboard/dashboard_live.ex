defmodule ArchiDepWeb.Dashboard.DashboardLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.LiveViewHelpers

  @impl LiveView
  def handle_params(_params, _url, socket) do
    auth = socket.assigns.auth
    set_process_label(__MODULE__, auth)

    noreply(socket)
  end
end
