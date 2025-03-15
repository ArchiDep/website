defmodule ArchiDep.Helpers.SchemaHelpers do
  @moduledoc """
  Utilities to manipulate Ecto schemas.
  """

  alias Ecto.UUID

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
end
