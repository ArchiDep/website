defmodule ArchiDep.Policy do
  @moduledoc """
  Authorization policy to grant or deny access to a context's resources.
  """

  alias ArchiDep.Authentication

  @doc """
  Checks whether an action can be performed with the current authentication.
  """
  @callback authorize(atom, atom, Authentication.t(), term) :: boolean
end
