defmodule ArchiDepWeb.Dashboard.DashboardLive do
  use ArchiDepWeb, :live_view

  @impl LiveView
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
end
