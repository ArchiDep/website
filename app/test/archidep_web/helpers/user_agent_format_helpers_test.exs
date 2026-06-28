defmodule ArchiDepWeb.Helpers.UserAgentFormatHelpersTest do
  use ExUnit.Case, async: true

  alias ArchiDepWeb.Helpers.UserAgentFormatHelpers

  describe "format_user_agent/1" do
    test "formats a recognized user agent as the browser on the operating system" do
      user_agent = "Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0"

      assert UserAgentFormatHelpers.format_user_agent(user_agent) == "Firefox on GNU/Linux"
    end

    test "returns the Unknown placeholder for an unrecognized user agent" do
      assert UserAgentFormatHelpers.format_user_agent("totally-not-a-user-agent") == "Unknown"
    end

    test "returns the Unknown placeholder for an empty user agent" do
      assert UserAgentFormatHelpers.format_user_agent("") == "Unknown"
    end
  end
end
