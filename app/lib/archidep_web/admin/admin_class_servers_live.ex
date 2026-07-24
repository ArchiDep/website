defmodule ArchiDepWeb.Admin.AdminClassServersLive do
  use ArchiDepWeb, :live_component

  import ArchiDepWeb.Servers.ServerComponents
  alias ArchiDep.Course.ClassView
  alias Phoenix.LiveView.JS

  @spec id(ClassView.t()) :: String.t()
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
