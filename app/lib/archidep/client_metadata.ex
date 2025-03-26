defmodule ArchiDep.ClientMetadata do
  @moduledoc """
  Handling of common business event metadata for the application.
  """

  import ArchiDep.Helpers.NetHelpers

  defstruct ip_address: nil, user_agent: nil

  @type t :: %__MODULE__{
          ip_address: :inet.ip_address() | nil,
          user_agent: String.t() | nil
        }

  @doc """
  Extracts valid metadata from the specified map, raising an error if any
  unexpected data is found.

  ## Examples

      iex> alias ArchiDep.ClientMetadata
      iex> ClientMetadata.new(nil, nil)
      %ClientMetadata{ip_address: nil, user_agent: nil}
      iex> ClientMetadata.new({1, 2, 3, 4}, nil)
      %ClientMetadata{ip_address: {1, 2, 3, 4}, user_agent: nil}
      iex> ClientMetadata.new(nil, "Mozilla/5.0")
      %ClientMetadata{ip_address: nil, user_agent: "Mozilla/5.0"}
      iex> ClientMetadata.new({1, 2, 3, 4}, "Mozilla/5.0"})
      %ClientMetadata{ip_address: {1, 2, 3, 4}, user_agent: "Mozilla/5.0"}

      iex> ClientMetadata.new({1, 2, 3, 4, 5}, "Mozilla/5.0")
      %ClientMetadata{ip_address: nil, user_agent: "Mozilla/5.0"}
  """
  @spec new(:inet.ip_address(), String.t()) :: t()
  def new(ip_address, user_agent) when is_ip_address(ip_address) do
    %__MODULE__{
      ip_address: validate_ip_address(ip_address),
      user_agent: user_agent
    }
  end

  defp validate_ip_address(ip_address) when is_ip_address(ip_address), do: ip_address
  defp validate_ip_address(_ip_address), do: nil
end
