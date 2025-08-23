defmodule Mix.Tasks.Recompile do
  @shortdoc "Force recompilation"

  @moduledoc """
  A custom Mix task to force recompilation of the project.
  """

  use Mix.Task

  @spec run(term()) :: :ok
  def run(_anything) do
    recompile_module = Path.join([File.cwd!(), "lib", "recompile.ex"])

    File.write!(recompile_module, """
    defmodule Recompile do
      @moduledoc false

      require Logger

      @recompile "#{DateTime.utc_now()}"

      Logger.info("Recompile module loaded at \#{@recompile}")
    end
    """)
  end
end
