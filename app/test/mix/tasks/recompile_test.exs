defmodule Mix.Tasks.RecompileTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Recompile

  @moduletag :tmp_dir

  describe "run/1" do
    # The module's only purpose is to be different from the last one written, so
    # what it is stamped with is the whole of what it says.
    test "writes a module stamped with the moment it was written", %{tmp_dir: tmp_dir} do
      file = Path.join([tmp_dir, "lib", "recompile.ex"])

      before_run = DateTime.utc_now()
      Recompile.run(["--output", file])
      after_run = DateTime.utc_now()

      contents = File.read!(file)
      assert [_line, stamp] = Regex.run(~r/@recompile "([^"]+)"/, contents)
      assert {:ok, written_at, 0} = DateTime.from_iso8601(stamp)

      assert DateTime.compare(written_at, before_run) in [:gt, :eq]
      assert DateTime.compare(written_at, after_run) in [:lt, :eq]

      assert contents == """
             defmodule Recompile do
               @moduledoc false

               require Logger

               @recompile "#{stamp}"

               Logger.info("Recompile module loaded at \#{@recompile}")
             end
             """
    end
  end
end
