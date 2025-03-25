defmodule ArchiDep.EventMetadata do
  @moduledoc """
  Handling of common business event metadata for the application.
  """

  import ArchiDep.Helpers.NetHelpers

  defstruct client_ip_address: nil, client_user_agent: nil

  @type t :: %__MODULE__{
          client_ip_address: :inet.ip_address() | nil,
          client_user_agent: String.t() | nil
        }

  @type serialized :: %{
          optional(String.t()) => String.t()
        }

  @doc """
  Extracts valid metadata from the specified map, raising an error if any
  unexpected data is found.

  ## Examples

      iex> import ArchiDep.EventMetadata
      iex> alias ArchiDep.EventMetadata
      iex> extract(%{})
      %EventMetadata{client_ip_address: nil, client_user_agent: nil}
      iex> extract(%{client_ip_address: {1, 2, 3, 4}})
      %EventMetadata{client_ip_address: {1, 2, 3, 4}, client_user_agent: nil}
      iex> extract(%{client_user_agent: "Mozilla/5.0"})
      %EventMetadata{client_ip_address: nil, client_user_agent: "Mozilla/5.0"}
      iex> extract(%{client_ip_address: {1, 2, 3, 4}, client_user_agent: "Mozilla/5.0"})
      %EventMetadata{client_ip_address: {1, 2, 3, 4}, client_user_agent: "Mozilla/5.0"}

      iex> ArchiDep.EventMetadata.extract(%{client_ip_address: {1, 2, 3, 4, 5}})
      ** (FunctionClauseError) no function clause matching in ArchiDep.EventMetadata.validate_ip_address/1
  """
  @spec extract(map) :: t()
  def extract(metadata) when is_map(metadata) do
    client_ip_address = Map.get(metadata, :client_ip_address)
    client_user_agent = Map.get(metadata, :client_user_agent)

    %__MODULE__{
      client_ip_address: validate_ip_address(client_ip_address),
      client_user_agent: validate_user_agent(client_user_agent)
    }
  end

  @spec client_ip_address(__MODULE__.t()) :: :inet.ip_address() | nil
  def client_ip_address(%__MODULE__{client_ip_address: client_ip_address}), do: client_ip_address

  @spec client_user_agent(__MODULE__.t()) :: String.t() | nil
  def client_user_agent(%__MODULE__{client_user_agent: client_user_agent}), do: client_user_agent

  @doc """
  Transforms valid metadata into a serializable map for database storage.

  ## Examples

      iex> import ArchiDep.EventMetadata
      iex> alias ArchiDep.EventMetadata
      iex> serialize(%EventMetadata{})
      %{}
      iex> serialize(%EventMetadata{client_ip_address: {1, 2, 3, 4}})
      %{"client_ip_address" => "1.2.3.4"}
      iex> serialize(%EventMetadata{client_user_agent: "Mozilla/5.0"})
      %{"client_user_agent" => "Mozilla/5.0"}
      iex> serialize(%EventMetadata{client_ip_address: {1, 2, 3, 4}, client_user_agent: "Mozilla/5.0"})
      %{"client_ip_address" => "1.2.3.4", "client_user_agent" => "Mozilla/5.0"}
  """
  @spec serialize(t()) :: serialized()
  def serialize(metadata) do
    %{}
    |> serialize_key(metadata, :client_ip_address, &serialize_ip_address/1)
    |> serialize_key(metadata, :client_user_agent, &Function.identity/1)
  end

  @doc """
  Serializes an IP address into a string.

  ## Examples

      iex> import ArchiDep.EventMetadata
      iex> serialize_ip_address({1, 2, 3, 4})
      "1.2.3.4"
      iex> serialize_ip_address({46_833, 10_531, 26_574, 53_935, 41_542, 21_716, 6_225, 8_172})
      "b6f1:2923:67ce:d2af:a246:54d4:1851:1fec"
      iex> serialize_ip_address({46_833, 0, 26_574, 0, 0, 0, 6_225, 8_172})
      "b6f1:0:67ce::1851:1fec"
  """
  @spec serialize_ip_address(:inet.ip_address()) :: String.t()
  def serialize_ip_address(ip_address) when is_ip_address(ip_address),
    do: ip_address |> :inet.ntoa() |> List.to_string()

  defp serialize_key(serialized, metadata, key, serializer)
       when is_map(serialized) and is_map(metadata) and is_atom(key) and
              is_function(serializer, 1) do
    if Map.has_key?(metadata, key) do
      value = Map.get(metadata, key)
      Map.put(serialized, Atom.to_string(key), serializer.(value))
    else
      serialized
    end
  end

  defp validate_ip_address(value) when is_ip_address(value), do: value
  defp validate_user_agent(value) when is_binary(value), do: value
end
