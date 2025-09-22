defmodule ArchiDep.Support.NetFactory do
  @moduledoc """
  Test fixtures for network-related data.
  """

  use ArchiDep.Support, :factory

  @spec ip_address() :: :inet.ip_address()
  def ip_address, do: if(bool(), do: ipv4_address(), else: ipv6_address())

  @spec ipv4_address() :: :inet.ip4_address()
  def ipv4_address,
    do:
      1..4
      |> Enum.map(fn _byte ->
        Faker.random_between(0, 255)
      end)
      |> List.to_tuple()

  @spec ipv6_address() :: :inet.ip6_address()
  def ipv6_address,
    do:
      1..8
      |> Enum.map(fn _byte ->
        Faker.random_between(0, 65_535)
      end)
      |> List.to_tuple()

  @spec postgrex_inet() :: Postgrex.INET.t()
  def postgrex_inet, do: %Postgrex.INET{address: ip_address(), netmask: nil}

  @spec port() :: 1..65_535
  def port, do: Faker.random_between(1, 65_535)
end
