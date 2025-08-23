defmodule Mix.Tasks.Recompile do
  @moduledoc """
  A custom Mix task to force recompilation of the project.
  """

  use Mix.Task

  @shortdoc "Force recompilation"
  def run(_) do
    recompile_module = Path.join([File.cwd!(), "lib", "recompile.ex"])

    File.write!(recompile_module, """
    defmodule Recompile do
      @moduledoc false
      @recompile "#{DateTime.utc_now()}"
      IO.puts("Recompile module loaded at \#{@recompile}")
    end
    """)
  end
end
