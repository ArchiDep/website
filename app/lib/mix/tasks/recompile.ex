defmodule Mix.Tasks.Recompile do
  @shortdoc "Force recompilation"

  @moduledoc """
  A custom Mix task to force recompilation of the project.

  Options:

  - `--output` — the file to write. Defaults to the `lib/recompile.ex` of the
    current directory, which is where it has to be for the project to be
    recompiled.
  """

  use Mix.Task

  @spec run(term()) :: :ok
  def run(args) do
    {opts, [], []} = OptionParser.parse(args, strict: [output: :string])

    recompile_module =
      Keyword.get_lazy(opts, :output, fn -> Path.join([File.cwd!(), "lib", "recompile.ex"]) end)

    File.mkdir_p!(Path.dirname(recompile_module))

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
