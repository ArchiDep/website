defmodule ArchiDepWeb.Channels.UserChannel do
  @moduledoc """
  User channel to connect the static frontend to the backend.
  """

  use Phoenix.Channel

  alias Phoenix.Channel

  @impl Channel
  def join("me", _message, socket) do
    auth = socket.assigns.auth

    {
      :ok,
      %{
        username: auth.username,
        roles: auth.roles,
        impersonating: auth.impersonated_id != nil,
        sessionId: auth.session_id,
        sessionExpiresAt: DateTime.to_iso8601(auth.session_expires_at)
      },
      socket
    }
  end
end
