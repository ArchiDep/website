defmodule ArchiDepWeb.Helpers.ConnHelpersTest do
  use ArchiDepWeb.Support.ConnCase, async: true

  alias ArchiDep.ClientMetadata
  alias ArchiDepWeb.Helpers.ConnHelpers

  describe "conn_metadata/1" do
    test "extracts the peer address and the user agent header" do
      conn =
        put_req_header(
          build_conn(),
          "user-agent",
          "Mozilla/5.0 (X11; Linux x86_64) Firefox/120.0"
        )

      assert ConnHelpers.conn_metadata(conn) == %ClientMetadata{
               ip_address: {127, 0, 0, 1},
               user_agent: "Mozilla/5.0 (X11; Linux x86_64) Firefox/120.0"
             }
    end

    test "leaves the user agent nil when the header is absent" do
      assert ConnHelpers.conn_metadata(build_conn()) == %ClientMetadata{
               ip_address: {127, 0, 0, 1},
               user_agent: nil
             }
    end
  end
end
