defmodule ArchiDep.Servers.Helpers do
  @moduledoc """
  Helpers for servers.
  """

  alias ArchiDep.Helpers.ProcessHelpers
  alias Ecto.UUID

  @spec set_process_label(atom(), UUID.t()) :: :ok
  def set_process_label(module, server_id) when is_binary(server_id),
    do: ProcessHelpers.set_process_label(module, "sr:#{String.slice(server_id, 0, 5)}")
end
