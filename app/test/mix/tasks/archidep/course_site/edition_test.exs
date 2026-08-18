defmodule Mix.Tasks.Archidep.CourseSite.EditionTest do
  # `Mix.shell/0` and the application environment are global to the VM.
  use ExUnit.Case, async: false

  import ArchiDep.Support.MixTaskTestHelpers

  alias Mix.Tasks.Archidep.CourseSite.Edition

  setup :capture_mix_shell

  describe "run/1" do
    test "prints the configured edition on a line of its own, for a shell to read" do
      put_course_site_config(version: "1998", years: "1998-1999")

      assert Edition.run([]) == :ok
      assert shell_output() == [{:info, "1998"}]
    end

    test "fails rather than printing nothing when no edition is configured" do
      put_course_site_config(years: "1997-1998")

      assert_raise Mix.Error, "No edition is configured", fn -> Edition.run([]) end
      assert shell_output() == []
    end

    test "fails when given an argument, which it would otherwise ignore" do
      put_course_site_config(version: "1996")

      assert_raise Mix.Error, "This task takes no arguments", fn -> Edition.run(["1995"]) end
      assert shell_output() == []
    end
  end
end
