defmodule ArchiDep.Support do
  @moduledoc """
  Reusable definitions for various types of test support modules.
  """

  @spec factory :: Macro.t()
  def factory do
    quote do
      use ExMachina.Ecto, repo: ArchiDep.Repo
      import ArchiDep.Support.DataCase, only: [not_loaded: 2]
      import ArchiDep.Support.FactoryHelpers
      alias Ecto.Association.NotLoaded
      alias Ecto.UUID
    end
  end

  @doc """
  When used, dispatch to the appropriate function.
  """
  @spec __using__(atom()) :: Macro.t()
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
