defmodule ArchiDepWeb.Helpers.SocketHelpersTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Support.Factory
  alias ArchiDepWeb.Helpers.SocketHelpers

  describe "live_socket_id/1" do
    test "builds the socket id from the authenticated principal" do
      auth = Factory.build(:authentication, principal_id: "11111000-0000-0000-0000-000000000000")

      assert SocketHelpers.live_socket_id(auth) == "auth:11111000-0000-0000-0000-000000000000"
    end
  end
end
