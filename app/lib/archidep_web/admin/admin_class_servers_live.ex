defmodule ArchiDepWeb.Admin.AdminClassServersLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Servers.ServerComponents
  alias ArchiDep.Course.Schemas.Class
  alias Phoenix.LiveView.JS

  @spec id(Class.t()) :: String.t()
  def id(class), do: "admin-class-#{class.id}-servers"

  @impl LiveComponent
  def mount(socket) do
    ok(socket)
  end

  @impl LiveComponent
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> ok()
  end
end
