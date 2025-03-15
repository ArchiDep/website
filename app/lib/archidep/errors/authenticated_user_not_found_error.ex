defmodule ArchiDep.Errors.AuthenticatedUserNotFoundError do
  @moduledoc """
  Exception raised when the user has successfully authenticated but can then no
  longer be found in the database, e.g. if it has been deleted between
  authentication and execution of the business logic.
  """

  defexception message: "The authenticated user cannot be found in the database."
end
