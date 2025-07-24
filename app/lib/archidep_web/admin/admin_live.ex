defmodule ArchiDepWeb.Admin.AdminLive do
  use ArchiDepWeb, :live_view

  import ArchiDepWeb.Helpers.LiveViewHelpers

  @impl LiveView
  def mount(_params, _session, socket) do
    auth = socket.assigns.auth

    if connected?(socket) do
      set_process_label(__MODULE__, auth)
    end

    ok(socket)
  end
end
