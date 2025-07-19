defmodule ArchiDep.Helpers.SchemaHelpers do
  @moduledoc """
  Helpers to manipulate `Ecto.Schema`s.
  """

  alias Ecto.UUID

  defdelegate trim(value), to: String

  @doc """
  Return the value if it is a non-blank string, otherwise return nil.

  ## Examples

      iex> import ArchiDep.Helpers.SchemaHelpers
      iex> trim_to_nil("  Hello, World!  ")
      "Hello, World!"
      iex> trim_to_nil("Hello, World!")
      "Hello, World!"
      iex> trim_to_nil("  ")
      nil
      iex> trim_to_nil(nil)
      nil
  """
  @spec trim_to_nil(String.t() | nil) :: String.t() | nil
  def trim_to_nil(nil), do: nil
  def trim_to_nil(value), do: value |> String.trim() |> non_empty_string_or_nil()

  @doc """
  Returns the value truncated to the specified maximum length if it is a string,
  otherwise returns nil.

  ## Examples

      iex> import ArchiDep.Helpers.SchemaHelpers
      iex> truncate("Hello, World!", 5)
      "Hello"
      iex> truncate("Hello, World!", 20)
      "Hello, World!"
      iex> truncate(nil, 10)
      nil
      iex> truncate("Short", 10)
      "Short"
  """
  @spec truncate(String.t() | nil, pos_integer()) :: String.t() | nil
  def truncate(nil, _max_length), do: nil
  def truncate(value, max_length) when is_binary(value), do: String.slice(value, 0, max_length)

  @doc """
  Return an OK tuple containing the specified UUID or an error tuple with the
  specified error if the value is not a valid UUID.

  ## Examples

      iex> import ArchiDep.Helpers.SchemaHelpers
      iex> uuid_or("550e8400-e29b-41d4-a716-446655440000", :invalid_uuid)
      {:ok, "550e8400-e29b-41d4-a716-446655440000"}
      iex> uuid_or("invalid-uuid", :invalid_uuid)
      {:error, :invalid_uuid}
  """
  @spec uuid_or(String.t(), atom) :: {:ok, UUID.t()} | {:error, atom}
  def uuid_or(id, error) when is_binary(id) and is_atom(error) do
    case UUID.cast(id) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> {:error, error}
    end
  end

  defp non_empty_string_or_nil(""), do: nil
  defp non_empty_string_or_nil(value), do: value
end
