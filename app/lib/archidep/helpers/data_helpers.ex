defmodule ArchiDep.Helpers.DataHelpers do
  alias Ecto.UUID

  def looks_like_an_email?(email) when is_binary(email),
    do: String.match?(email, ~r/\A.+@.+\..+\z/)

  @doc """
  Ensures that the specified ID is a valid UUID, or returns the specified error.
  """
  @spec validate_uuid(binary(), atom()) :: :ok | {:error, atom()}
  def validate_uuid(id, error) when is_binary(id) do
    case UUID.cast(id) do
      {:ok, _uuid} -> :ok
      :error -> {:error, error}
    end
  end
end
