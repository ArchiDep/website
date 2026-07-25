defmodule ArchiDep.CourseSite.Urls.UrlError do
  @moduledoc """
  Raised when a logical reference cannot be resolved to a URL, e.g. an image
  that does not exist next to the page referring to it.
  """

  defexception [:message]

  @impl Exception
  def exception(message) when is_binary(message), do: %__MODULE__{message: message}
end
