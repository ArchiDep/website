defmodule ArchiDep.Servers.Helpers do
  alias ArchiDep.Helpers.ProcessHelpers
  alias Ecto.UUID

  # TODO: automatically import this in all gen servers
  @spec set_process_label(atom(), UUID.t()) :: :ok
  def set_process_label(module, server_id) when is_binary(server_id),
    do: ProcessHelpers.set_process_label(module, String.slice(server_id, 0, 5))
end
