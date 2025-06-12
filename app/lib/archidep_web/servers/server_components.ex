defmodule ArchiDepWeb.Servers.ServerComponents do
  use Phoenix.Component

  alias ArchiDep.Servers.Schemas.Server

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
end
