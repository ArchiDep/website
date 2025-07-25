defmodule ArchiDepWeb.Helpers.SocketHelpers do
  @moduledoc """
  Helper functions for working with Phoenix sockets.
  """

  import ArchiDep.Authentication, only: [is_authentication: 1]
  alias ArchiDep.Authentication

  @spec live_socket_id(Authentication.t()) :: String.t()
  def live_socket_id(auth) when is_authentication(auth),
    do: "auth:#{Authentication.principal_id(auth)}"
end
