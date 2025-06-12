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
