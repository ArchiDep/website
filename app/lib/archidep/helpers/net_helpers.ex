defmodule ArchiDep.Helpers.NetHelpers do
  @moduledoc """
  Network-related helper functions.
  """

  @type network_port :: 1..65_535

  defguardp is_ipv4_address_part(value) when is_integer(value) and value >= 0 and value <= 255
  defguardp is_ipv6_address_part(value) when is_integer(value) and value >= 0 and value <= 65_535

  @doc """
  Returns true if `term` is an IPv4 address.

  ## Examples

      iex> import ArchiDep.Helpers.NetHelpers
      iex> is_ipv4_address({1, 2, 3, 4})
      true
      iex> is_ipv4_address({192, 168, 50, 4})
      true
      iex> is_ipv4_address({-100, 0, 100, 200})
      false
      iex> is_ipv4_address({1, 2, 3, 4, 5, 6, 7, 8})
      false
      iex> is_ipv4_address(:foo)
      false
  """
  @spec is_ipv4_address(term) :: Macro.t()
  defguard is_ipv4_address(value)
           when is_tuple(value) and tuple_size(value) == 4 and
                  is_ipv4_address_part(elem(value, 0)) and is_ipv4_address_part(elem(value, 1)) and
                  is_ipv4_address_part(elem(value, 2)) and is_ipv4_address_part(elem(value, 3))

  @doc """
  Returns true if `term` is an IPv6 address.

  ## Examples

      iex> import ArchiDep.Helpers.NetHelpers
      iex> is_ipv6_address({1, 2, 3, 4, 5, 6, 7, 8})
      true
      iex> is_ipv6_address({2, 4, 8, 16, 32, 64, 128, 256})
      true
      iex> is_ipv6_address({-4, -3, -2, -1, 0, 1, 2, 3})
      false
      iex> is_ipv6_address({1, 2, 3, 4})
      false
      iex> is_ipv6_address(:foo)
      false
  """
  @spec is_ipv6_address(term) :: Macro.t()
  defguard is_ipv6_address(value)
           when is_tuple(value) and tuple_size(value) == 8 and
                  is_ipv6_address_part(elem(value, 0)) and is_ipv6_address_part(elem(value, 1)) and
                  is_ipv6_address_part(elem(value, 2)) and is_ipv6_address_part(elem(value, 3)) and
                  is_ipv6_address_part(elem(value, 4)) and is_ipv6_address_part(elem(value, 5)) and
                  is_ipv6_address_part(elem(value, 6)) and is_ipv6_address_part(elem(value, 7))

  @doc """
  Returns true if `term` is an IP address.

  ## Examples

      iex> import ArchiDep.Helpers.NetHelpers
      iex> is_ip_address({1, 2, 3, 4})
      true
      iex> is_ip_address({1, 2, 3, 4, 5, 6, 7, 8})
      true
      iex> is_ip_address({-1, 0, 1, 2})
      false
      iex> is_ip_address(:foo)
      false
  """
  @spec is_ip_address(term) :: Macro.t()
  defguard is_ip_address(value) when is_ipv4_address(value) or is_ipv6_address(value)

  @doc """
  Returns true if `term` is a valid port number.

  ## Examples

      iex> import ArchiDep.Helpers.NetHelpers
      iex> is_network_port(80)
      true
      iex> is_network_port(5432)
      true
      iex> is_network_port(65_535)
      true
      iex> is_network_port(0)
      false
      iex> is_network_port(-1)
      false
      iex> is_network_port(65536)
      false
      iex> is_network_port(:foo)
      false
  """
  @spec is_network_port(term) :: Macro.t()
  defguard is_network_port(value) when is_integer(value) and value > 0 and value < 65_536

  @doc """
  Converts an HTTP URI into a WebSocket URI.

  ## Examples

      iex> import ArchiDep.Helpers.NetHelpers
      iex> {:ok, http_uri} = URI.new("http://example.com")
      iex> to_ws_uri(http_uri)
      %URI{scheme: "ws", host: "example.com", port: 80}
      iex> {:ok, https_uri} = URI.new("https://example.com/foo/bar")
      iex> to_ws_uri(https_uri)
      %URI{scheme: "wss", host: "example.com", port: 443, path: "/foo/bar"}
  """
  @spec to_ws_uri(URI.t()) :: URI.t()
  def to_ws_uri(%URI{scheme: "http"} = uri), do: %URI{uri | scheme: "ws"}
  def to_ws_uri(%URI{scheme: "https"} = uri), do: %URI{uri | scheme: "wss"}
end
