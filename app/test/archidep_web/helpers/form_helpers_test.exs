defmodule ArchiDepWeb.Helpers.FormHelpersTest do
  use ExUnit.Case, async: true

  alias ArchiDepWeb.Helpers.FormHelpers

  describe "tmp_boolify/2" do
    test "converts the value true at the key to the boolean true" do
      assert FormHelpers.tmp_boolify(%{"flag" => "true", "other" => "kept"}, "flag") ==
               %{"flag" => true, "other" => "kept"}
    end

    test "converts the value false at the key to the boolean false" do
      assert FormHelpers.tmp_boolify(%{"flag" => "false", "other" => "kept"}, "flag") ==
               %{"flag" => false, "other" => "kept"}
    end

    test "returns the params unchanged when the key is absent" do
      assert FormHelpers.tmp_boolify(%{"other" => "kept"}, "flag") == %{"other" => "kept"}
    end

    test "returns the params unchanged when the value is not a boolean string" do
      assert FormHelpers.tmp_boolify(%{"flag" => "maybe"}, "flag") == %{"flag" => "maybe"}
    end
  end

  describe "process_boolean/1" do
    test "passes a boolean through unchanged" do
      assert FormHelpers.process_boolean(true) == {:ok, true}
      assert FormHelpers.process_boolean(false) == {:ok, false}
    end

    test "parses the boolean strings true and false" do
      assert FormHelpers.process_boolean("true") == {:ok, true}
      assert FormHelpers.process_boolean("false") == {:ok, false}
    end

    test "returns :error for anything else" do
      assert FormHelpers.process_boolean("yes") == :error
      assert FormHelpers.process_boolean(nil) == :error
      assert FormHelpers.process_boolean(1) == :error
    end
  end

  describe "process_integer/1" do
    test "passes an integer through unchanged" do
      assert FormHelpers.process_integer(22) == {:ok, 22}
    end

    test "parses a string that is entirely an integer" do
      assert FormHelpers.process_integer("22") == {:ok, 22}
    end

    test "returns :error for a string that is not entirely an integer" do
      assert FormHelpers.process_integer("22x") == :error
      assert FormHelpers.process_integer("x") == :error
      assert FormHelpers.process_integer("") == :error
    end

    test "returns :error for a non-integer, non-binary value" do
      assert FormHelpers.process_integer(nil) == :error
    end
  end

  describe "process_ip_address/1" do
    test "parses an IPv4 address string into an address tuple" do
      assert FormHelpers.process_ip_address("127.0.0.1") == {:ok, {127, 0, 0, 1}}
    end

    test "parses an IPv6 address string into an address tuple" do
      assert FormHelpers.process_ip_address("2001:db8::1") ==
               {:ok, {8193, 3512, 0, 0, 0, 0, 0, 1}}
    end

    test "returns the raw :inet error for a malformed address string" do
      assert FormHelpers.process_ip_address("not an ip") == {:error, :einval}
    end

    test "returns :error for a non-binary value" do
      assert FormHelpers.process_ip_address(nil) == :error
    end
  end

  describe "display_ip_address/1" do
    test "formats an IPv4 address tuple as a string" do
      assert FormHelpers.display_ip_address({127, 0, 0, 1}) == "127.0.0.1"
    end

    test "formats an IPv6 address tuple as a string" do
      assert FormHelpers.display_ip_address({8193, 3512, 0, 0, 0, 0, 0, 1}) == "2001:db8::1"
    end
  end
end
