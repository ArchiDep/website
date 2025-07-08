defmodule ArchiDep.Servers.Errors.ServerOwnerNotFoundError do
  @moduledoc """
  Exception raised when a known server owner can no longer be found in the
  database, e.g. if it has been deleted between creation and execution of the
  business logic.
  """

  defexception message: "The server owner cannot be found in the database."
end
