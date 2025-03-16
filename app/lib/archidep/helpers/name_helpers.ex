defmodule ArchiDep.Helpers.NameHelpers do
  @moduledoc """
  Helper functions to work with names.
  """

  @doc """
  Transforms a camel-case string into an underscored string.

  ## Examples

      iex> import ArchiDep.Helpers.NameHelpers
      iex> underscore("Foo")
      "foo"
      iex> underscore("FooBar")
      "foo_bar"
      iex> underscore("FooBarBaz")
      "foo_bar_baz"
      iex> underscore("FooBAR")
      "foo_bar"
      iex> underscore("FOOBar")
      "foo_bar"
      iex> underscore("FBar")
      "f_bar"
  """
  @spec underscore(String.t()) :: String.t()
  def underscore(camelcase) do
    camelcase
    # Replace leading uppercase fragments (e.g. "FOOBarBaz" -> "foo_barBaz").
    |> String.replace(~r/[A-Z]{2,}[a-z]/u, &replace_leading_uppercase_fragment/1)
    # Replace remaining uppercase fragment (e.g. "foo_barBaz" -> "foo_bar_baz").
    |> String.replace(~r/(?:[^A-Z])?[A-Z]+/u, &replace_uppercase_fragment/1)
  end

  defp replace_leading_uppercase_fragment(fragment) do
    {uppercase_part, last_character} = String.split_at(fragment, -1)
    {uppercase_start, uppercase_last} = String.split_at(uppercase_part, -1)

    String.downcase(uppercase_start) <> "_" <> String.downcase(uppercase_last) <> last_character
  end

  defp replace_uppercase_fragment(fragment) do
    {first_character, rest} = String.split_at(fragment, 1)

    if String.upcase(first_character) != first_character do
      String.downcase(first_character) <> "_" <> String.downcase(rest)
    else
      String.downcase(fragment)
    end
  end
end
