defmodule ArchiDep.Support.TokenTestHelpersTest do
  use ExUnit.Case, async: true

  import ArchiDep.Support.TokenTestHelpers

  doctest ArchiDep.Support.TokenTestHelpers

  describe "assert_secure_random_token/1" do
    test "accepts a securely generated random token and returns it" do
      token = :crypto.strong_rand_bytes(100)
      assert assert_secure_random_token(token) == token
    end

    test "accepts a session-style token (timestamp prefix + random bytes)" do
      token = <<123_456_789::64>> <> :crypto.strong_rand_bytes(50)
      assert assert_secure_random_token(token) == token
    end

    test "accepts a token exactly at the length and entropy floors" do
      # 32 bytes, all distinct: exactly on both thresholds.
      token = :binary.list_to_bin(Enum.to_list(0..31))
      assert assert_secure_random_token(token) == token
    end

    test "accepts a long token exactly at the entropy floor" do
      # 44 bytes but only 24 distinct byte values (0..23): exactly on the floor.
      token = :binary.list_to_bin(Enum.to_list(0..23) ++ List.duplicate(0, 20))
      assert assert_secure_random_token(token) == token
    end

    test "rejects a token that is too short" do
      token = :binary.list_to_bin(Enum.to_list(0..30))

      assert_raise ExUnit.AssertionError, ~r/at least 32 bytes/, fn ->
        assert_secure_random_token(token)
      end
    end

    test "rejects an empty token" do
      assert_raise ExUnit.AssertionError, ~r/at least 32 bytes/, fn ->
        assert_secure_random_token("")
      end
    end

    test "rejects a long but low-entropy token" do
      # 60 bytes (well past the length floor) but only 5 distinct byte values,
      # like a hand-written placeholder.
      token = String.duplicate("secret", 10)

      assert_raise ExUnit.AssertionError, ~r/distinct byte/, fn ->
        assert_secure_random_token(token)
      end
    end

    test "rejects a long token just below the entropy floor" do
      # 43 bytes but only 23 distinct byte values (0..22): one short of the floor.
      token = :binary.list_to_bin(Enum.to_list(0..22) ++ List.duplicate(0, 20))

      assert_raise ExUnit.AssertionError, ~r/distinct byte/, fn ->
        assert_secure_random_token(token)
      end
    end
  end
end
