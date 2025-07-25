defmodule ArchiDepWeb.LiveHooks do
  @moduledoc """
  Phoenix LiveView hooks for the application.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4]
  alias Phoenix.LiveView.Socket

  @spec on_mount(atom(), map(), map(), Socket.t()) ::
          {:cont, Socket.t()} | {:halt, Socket.t()}
  def on_mount(:default, _params, _session, socket),
    do: {:cont, attach_hook(socket, :assign_current_path, :handle_params, &assign_current_path/3)}

  defp assign_current_path(_params, url, socket) do
    uri = URI.parse(url)
    {:cont, assign(socket, :current_path, uri.path)}
  end
end
