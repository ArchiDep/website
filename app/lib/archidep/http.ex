defmodule ArchiDep.Http do
  @moduledoc """
  HTTP client module.
  """

  @behaviour ArchiDep.Http.Behaviour
  @implementation Application.compile_env!(:archidep, __MODULE__)

  defdelegate get(url, opts \\ []), to: @implementation
end
