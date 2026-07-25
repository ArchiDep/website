defmodule ArchiDep.CourseSite.Renderer.Liquid.TagsTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Renderer.Liquid.IncludeTag
  alias ArchiDep.CourseSite.Renderer.Liquid.LinkTag
  alias ArchiDep.CourseSite.Renderer.Liquid.Tags

  describe "default/0" do
    test "is Liquid's own tags, without the one that would need a file system, plus the course's" do
      assert Tags.default() ==
               Solid.Tag.default_tags()
               |> Map.delete("render")
               |> Map.merge(%{"include" => IncludeTag, "link" => LinkTag})
    end
  end
end
