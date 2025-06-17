defmodule ArchiDepWeb.Servers.ServerComponents do
  use Phoenix.Component

  alias ArchiDep.Servers.Schemas.Server
  alias ArchiDep.Servers.Schemas.ServerRealTimeState

  attr :server, Server, doc: "the server whose name to display"

  def server_name(assigns) do
    ~H"""
    <%= if @server.name do %>
      {@server.name}
    <% else %>
      <span class="font-mono">
        {Server.default_name(@server)}
      </span>
    <% end %>
    """
  end

  attr :server, Server, doc: "the server to display"
  attr :state, ServerRealTimeState, doc: "the current state of the server", default: nil

  def server_card(assigns) do
    ~H"""
    <div class="card bg-error text-error-content">
      <div class="card-body">
        <div class="card-title flex justify-between">
          <h2 class="flex items-center gap-x-2">
            <Heroicons.server solid class="size-6" />
            <.server_name server={@server} />
          </h2>
          <div class="badge badge-soft badge-error">Offline</div>
        </div>
        <p>
          Not connected to this server yet.
        </p>
      </div>
    </div>
    """
  end
end
