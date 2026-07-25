defmodule ArchiDep.CourseSite.Renderer.Liquid.RawMarkupTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Renderer.Liquid.RawMarkup

  describe "parse/1" do
    test "reads markup a Liquid lexer would refuse" do
      assert parse("_course/101-command-line/subject.md %}the rest") ==
               {:ok, "_course/101-command-line/subject.md",
                %{rest: "the rest", line: 1, column: 39}}
    end

    test "reads markup written across several lines" do
      assert parse("_course/803-docker-isolation/subject.md\n  %}the rest") ==
               {:ok, "_course/803-docker-isolation/subject.md",
                %{rest: "the rest", line: 2, column: 5}}
    end

    test "reads markup whose tag asks for the whitespace around it to go away" do
      assert parse("icons/photo.html class=\"size-6\" -%}the rest") ==
               {:ok, "icons/photo.html class=\"size-6\"",
                %{rest: "the rest", line: 1, column: 36}}
    end

    test "reads a tag that has no markup at all" do
      assert parse("%}the rest") == {:ok, "", %{rest: "the rest", line: 1, column: 3}}
    end

    test "reports a tag that is never closed" do
      assert parse("_course/101-command-line/subject.md") ==
               {:error, "Tag not terminated, expected %}", %{line: 1, column: 36}}
    end
  end

  defp parse(rest) do
    context = %Solid.ParserContext{rest: rest, line: 1, column: 1, mode: :normal}

    case RawMarkup.parse(context) do
      {:ok, markup, context} ->
        {:ok, markup, %{rest: context.rest, line: context.line, column: context.column}}

      {:error, reason, loc} ->
        {:error, reason, loc}
    end
  end
end
