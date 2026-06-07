defmodule ArchiDepWeb.Channels.UserSocketTest do
  use ArchiDepWeb.Support.ChannelCase, async: true

  test "refuses to connect without a token" do
    assert connect(UserSocket, %{}) == {:error, :missing_token}
  end
end
