defmodule ArchiDep.Events.Errors.EventHasNoIdentityError do
  @moduledoc """
  Raised when no identity can be retrieved from a business event.
  """

  defexception message: "Event has no identity"
end
