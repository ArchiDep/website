defmodule ArchiDep.Helpers.ProcessHelpers do
  @moduledoc """
  Helpers to work with processes.
  """

  @spec set_process_label(atom()) :: :ok
  def set_process_label(module) when is_atom(module),
    do: :proc_lib.set_label(Atom.to_string(module))

  @spec set_process_label(atom(), String.t()) :: :ok
  def set_process_label(module, addition) when is_atom(module) and is_binary(addition),
    do: :proc_lib.set_label("#{Atom.to_string(module)}|#{addition}")
end
