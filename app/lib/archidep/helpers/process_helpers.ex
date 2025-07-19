defmodule ArchiDep.Helpers.ProcessHelpers do
  @moduledoc """
  Helpers to work with processes.
  """

  @doc """
  Sets the label of the current process to the given module name.

  ## Examples

      iex> import ArchiDep.Helpers.ProcessHelpers
      iex> alias ArchiDep.Helpers.ProcessHelpers
      iex> set_process_label(ProcessHelpers)
      :ok
      iex> :proc_lib.get_label(self())
      "Elixir.ArchiDep.Helpers.ProcessHelpers"
  """
  @spec set_process_label(atom()) :: :ok
  def set_process_label(module) when is_atom(module),
    do: :proc_lib.set_label(Atom.to_string(module))

  @doc """
  Sets the label of the current process to the given module name with an additional string.
  This is useful for distinguishing between different instances of the same module.

  ## Examples

      iex> import ArchiDep.Helpers.ProcessHelpers
      iex> alias ArchiDep.Helpers.ProcessHelpers
      iex> set_process_label(ProcessHelpers, "instance_1")
      :ok
      iex> :proc_lib.get_label(self())
      "Elixir.ArchiDep.Helpers.ProcessHelpers|instance_1"
  """
  @spec set_process_label(atom(), String.t()) :: :ok
  def set_process_label(module, addition) when is_atom(module) and is_binary(addition),
    do: :proc_lib.set_label("#{Atom.to_string(module)}|#{addition}")
end
