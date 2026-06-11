defmodule ArchiDep.Support.TokenTestHelpers do
  @moduledoc """
  Helper assertions for randomly generated secret tokens, such as login-link
  tokens and session tokens.
  """

  import ExUnit.Assertions

  # A securely generated token cannot be pinned to an exact value, but it can
  # be checked for the two properties that make it a usable secret: it must be
  # long enough, and it must actually be random. These are conservative floors,
  # well below what `:crypto.strong_rand_bytes/1` produces but well above any
  # plausible hand-written placeholder.
  @minimum_token_bytes 32
  @minimum_token_distinct_bytes 24

  @doc """
  Asserts that a token looks like a securely generated random secret: at least
  #{@minimum_token_bytes} bytes long and carrying real entropy (at least
  #{@minimum_token_distinct_bytes} distinct byte values). Returns the token so
  it can be used in a pipeline.

  The exact value of a token built from `:crypto.strong_rand_bytes/1` is
  unpredictable, so it is bound and cross-referenced rather than asserted by
  equality. This guards the two properties equality cannot: that the token is
  long enough, and that it is not a low-entropy stand-in. Counting distinct
  byte values is a cheap entropy floor — random bytes yield dozens of distinct
  values, whereas a hand-written placeholder such as `"seeeeeecret"` has only a
  handful.

  ## Examples

      iex> import ArchiDep.Support.TokenTestHelpers
      iex> token = <<0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
      ...>           17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31>>
      iex> assert_secure_random_token(token) == token
      true
  """
  @spec assert_secure_random_token(binary()) :: binary()
  def assert_secure_random_token(token) when is_binary(token) do
    assert byte_size(token) >= @minimum_token_bytes,
           "expected a token of at least #{@minimum_token_bytes} bytes, " <>
             "got #{byte_size(token)}"

    distinct_bytes = token |> :binary.bin_to_list() |> Enum.uniq() |> length()

    assert distinct_bytes >= @minimum_token_distinct_bytes,
           "expected a token with at least #{@minimum_token_distinct_bytes} distinct byte " <>
             "values (entropy floor), got #{distinct_bytes}"

    token
  end
end
