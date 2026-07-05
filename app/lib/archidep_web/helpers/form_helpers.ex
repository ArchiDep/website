defmodule ArchiDepWeb.Helpers.FormHelpers do
  @moduledoc """
  Helper functions for web form handling.
  """

  @spec tmp_boolify(map(), String.t()) :: map()
  def tmp_boolify(params, key) when is_binary(key) do
    case params do
      %{^key => "true"} -> %{params | key => true}
      %{^key => "false"} -> %{params | key => false}
      _anything_else -> params
    end
  end

  @spec process_boolean(term()) :: {:ok, boolean()} | :error
  def process_boolean(value) when is_boolean(value), do: {:ok, value}
  def process_boolean("true"), do: {:ok, true}
  def process_boolean("false"), do: {:ok, false}
  def process_boolean(_value), do: :error

  @spec process_integer(term()) :: {:ok, integer()} | :error
  def process_integer(value) when is_integer(value), do: {:ok, value}

  def process_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      _anything_else -> :error
    end
  end

  def process_integer(_value), do: :error

  @spec process_ip_address(term()) :: {:ok, :inet.ip_address()} | {:error, :einval} | :error
  def process_ip_address(value) when is_binary(value),
    do: value |> to_charlist() |> :inet.parse_address()

  def process_ip_address(_value), do: :error

  @spec display_ip_address(:inet.ip_address()) :: String.t()
  def display_ip_address(addr) when is_tuple(addr), do: addr |> :inet.ntoa() |> to_string()
end
