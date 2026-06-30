defmodule ArchiDep.Cmd.Behaviour do
  @moduledoc """
  Behaviour of the module used to run external commands and stream their output.
  """

  @callback stream(command :: nonempty_list(String.t()), opts :: keyword()) ::
              Enumerable.t(binary() | {:exit, {:status, non_neg_integer()} | :epipe})
end
