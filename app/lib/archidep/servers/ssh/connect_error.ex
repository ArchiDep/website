defmodule ArchiDep.Servers.SSH.ConnectError do
  @moduledoc """
  The connection failures the Erlang `:ssh` library reports as strings, and
  their classification into stable atoms.

  `ArchiDep.Servers.SSH.Client.connect/3` surfaces certain failures as raw
  charlist strings straight from `:ssh`, and
  `ArchiDep.Servers.ServerTracking.ServerConnection` keys off them to return
  stable error atoms. This module owns those strings in one place: the tuple
  constructors build the exact `{:error, reason}` a failed connection returns
  (used to drive the mocked mapping tests), and `classify/1` maps a reason to
  its atom (used by production). The external-tool compatibility tests certify
  that real `:ssh` still emits these strings (see the "Testing external-tool
  compatibility" section in `docs/testing.md`).
  """

  @authentication_failed_reason ~c"Unable to connect using the available authentication methods"
  @key_exchange_failed_reason ~c"Key exchange failed"

  @type reason :: charlist()
  @type classification :: :authentication_failed | :key_exchange_failed | :other

  @doc """
  The error tuple `:ssh` returns when no offered authentication method succeeds.
  """
  @spec authentication_failed() :: {:error, reason()}
  def authentication_failed, do: {:error, @authentication_failed_reason}

  @doc """
  The error tuple `:ssh` returns when the client and server share no key-exchange
  algorithm.
  """
  @spec key_exchange_failed() :: {:error, reason()}
  def key_exchange_failed, do: {:error, @key_exchange_failed_reason}

  @doc """
  Classifies an `:ssh` connection error reason into a stable atom, returning
  `:other` for any reason without a specific classification.
  """
  @spec classify(term()) :: classification()
  def classify(@authentication_failed_reason), do: :authentication_failed
  def classify(@key_exchange_failed_reason), do: :key_exchange_failed
  def classify(_reason), do: :other
end
