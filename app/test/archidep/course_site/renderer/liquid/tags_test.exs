defmodule ArchiDep.CourseSite.Renderer.Liquid.TagsTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Renderer.Liquid.CalloutTag
  alias ArchiDep.CourseSite.Renderer.Liquid.ColsTag
  alias ArchiDep.CourseSite.Renderer.Liquid.IncludeTag
  alias ArchiDep.CourseSite.Renderer.Liquid.LinkTag
  alias ArchiDep.CourseSite.Renderer.Liquid.MarkdownTag
  alias ArchiDep.CourseSite.Renderer.Liquid.MermaidTag
  alias ArchiDep.CourseSite.Renderer.Liquid.NoteTag
  alias ArchiDep.CourseSite.Renderer.Liquid.SolutionTag
  alias ArchiDep.CourseSite.Renderer.Liquid.Tags

  describe "default/0" do
    test "is Liquid's own tags, without the one that would need a file system, plus the course's" do
      assert Tags.default() ==
               Solid.Tag.default_tags()
               |> Map.delete("render")
               |> Map.merge(%{
                 "callout" => CalloutTag,
                 "cols" => ColsTag,
                 "include" => IncludeTag,
                 "link" => LinkTag,
                 "markdown" => MarkdownTag,
                 "mermaid" => MermaidTag,
                 "note" => NoteTag,
                 "solution" => SolutionTag
               })
    end
  end
end
