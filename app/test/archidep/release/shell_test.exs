defmodule ArchiDep.Release.ShellTest do
  use ExUnit.Case, async: true

  alias ArchiDep.Release.Shell

  describe "shell_escape/1" do
    test "leaves an argument made only of safe characters unquoted" do
      assert Shell.shell_escape(["safe_arg-1/path:key=value"]) == "safe_arg-1/path:key=value"
    end

    test "single-quotes an argument containing an unsafe character" do
      assert Shell.shell_escape(["hello world"]) == "'hello world'"
    end

    test "escapes an embedded single quote" do
      assert Shell.shell_escape(["it's"]) == "'it'\\''s'"
    end

    test "joins multiple arguments with spaces, escaping each independently" do
      assert Shell.shell_escape(["ls", "-la", "my dir"]) == "ls -la 'my dir'"
    end

    test "returns an empty string for no arguments" do
      assert Shell.shell_escape([]) == ""
    end
  end

  describe "format_maybe_empty_stream/1" do
    test "renders an empty stream as a marker" do
      assert Shell.format_maybe_empty_stream("") == " (empty)"
    end

    test "renders a non-empty stream on a new line" do
      assert Shell.format_maybe_empty_stream("output") == "\noutput"
    end
  end

  describe "format_stream/1" do
    test "trims and renders a non-empty stream on a new line" do
      assert Shell.format_stream("  output  ") == "\noutput"
    end

    test "renders a blank stream as the empty marker" do
      assert Shell.format_stream("   ") == " (empty)"
    end
  end
end
