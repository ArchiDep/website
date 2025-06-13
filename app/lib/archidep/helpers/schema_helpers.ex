defmodule ArchiDep.Helpers.SchemaHelpers do
  @moduledoc """
  Utilities to manipulate Ecto schemas.
  """

  alias Ecto.UUID

  defdelegate trim(value), to: String

  @doc """
  Return the value if it is a non-blank string, otherwise return nil.
  """
  @spec trim_to_nil(String.t() | nil) :: String.t() | nil
  def trim_to_nil(nil), do: nil
  def trim_to_nil(value), do: value |> String.trim() |> non_empty_string_or_nil()

  @doc """
  Returns the value truncated to the specified maximum length if it is a string,
  otherwise returns nil.
  """
  @spec truncate(String.t() | nil, pos_integer()) :: String.t() | nil
  def truncate(nil, _max_length), do: nil
  def truncate(value, max_length) when is_binary(value), do: String.slice(value, 0, max_length)

  @doc """
  Return an OK tuple containing the specified UUID or an error tuple with the
  specified error if the value is not a valid UUID.
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
