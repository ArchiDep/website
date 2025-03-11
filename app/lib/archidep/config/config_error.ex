defmodule ArchiDep.Config.ConfigError do
  @moduledoc """
  Raised when a configuration-related issue occurs, e.g. a configuration value
  is missing or is invalid.
  """

  defexception [:message]

  @impl Exception
  def exception(message) when is_binary(message) do
    %__MODULE__{message: message}
  end
end
