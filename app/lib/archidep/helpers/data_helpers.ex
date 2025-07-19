defmodule ArchiDep.Helpers.DataHelpers do
  @moduledoc """
  Helper functions for data validation and manipulation.
  """

  alias Ecto.UUID

  @doc """
  Checks if the given string looks like an email address.

  ## Examples

      iex> import ArchiDep.Helpers.DataHelpers
      iex> looks_like_an_email?("example@archidep.ch")
      true
      iex> looks_like_an_email?("a@b.c")
      true
      iex> looks_like_an_email?("not-an-email")
      false
      iex> looks_like_an_email?("example@archidep")
      false
      iex> looks_like_an_email?("example@.ch")
      false
  """
  @spec looks_like_an_email?(String.t()) :: boolean()
  def looks_like_an_email?(email) when is_binary(email),
    do: String.match?(email, ~r/\A.+@.+\..+\z/)

  @doc """
  Ensures that the specified ID is a valid UUID, or returns the specified error.

  ## Examples

      iex> import ArchiDep.Helpers.DataHelpers
      iex> validate_uuid("550e8400-e29b-41d4-a716-446655440000", :invalid_uuid)
      :ok
      iex> validate_uuid("invalid-uuid", :invalid_uuid)
      {:error, :invalid_uuid}
  """
  @spec validate_uuid(binary(), atom()) :: :ok | {:error, atom()}
  def validate_uuid(id, error) when is_binary(id) and is_atom(error) do
    case UUID.cast(id) do
      {:ok, _uuid} -> :ok
      :error -> {:error, error}
    end
  end
end
