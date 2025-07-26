defmodule ArchiDepWeb.Channels.UserChannel do
  @moduledoc """
  User channel to connect the static frontend to the backend.
  """

  use Phoenix.Channel

  alias ArchiDepWeb.ClientSessionData
  alias Phoenix.Channel

  @impl Channel
  def join("me", _message, socket) do
    auth = socket.assigns.auth
    {:ok, ClientSessionData.new(auth), socket}
  end
end
