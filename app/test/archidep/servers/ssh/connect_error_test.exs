defmodule ArchiDep.Servers.SSH.ConnectErrorTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Servers.SSH.ConnectError

  describe "classify/1" do
    test "classifies the authentication-failure tuple's reason" do
      {:error, reason} = ConnectError.authentication_failed()

      assert ConnectError.classify(reason) == :authentication_failed
    end

    test "classifies the key-exchange-failure tuple's reason" do
      {:error, reason} = ConnectError.key_exchange_failed()

      assert ConnectError.classify(reason) == :key_exchange_failed
    end

    test "classifies an unrecognized string reason as :other" do
      assert ConnectError.classify(~c"Connection refused") == :other
    end

    test "classifies a non-string reason as :other" do
      assert ConnectError.classify(:econnrefused) == :other
    end
  end
end
