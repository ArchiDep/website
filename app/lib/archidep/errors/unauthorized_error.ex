defmodule ArchiDep.Errors.UnauthorizedError do
  @moduledoc """
  Exception raised when the user has successfully authenticated but is not
  allowed to perform an operation due to insufficient permissions.
  """

  @type t :: %__MODULE__{
          message: String.t(),
          context: atom,
          action: atom
        }

  @enforce_keys [:context, :action]
  defexception message:
                 "The authenticated user does not have sufficient permissions to perform this operation.",
               context: nil,
               action: nil
end
