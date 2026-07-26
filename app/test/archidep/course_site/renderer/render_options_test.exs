defmodule ArchiDep.CourseSite.Renderer.RenderOptionsTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.Renderer.EmojiImages
  alias ArchiDep.CourseSite.Renderer.ExternalLinks
  alias ArchiDep.CourseSite.Renderer.Liquid.LinkTag
  alias ArchiDep.CourseSite.Renderer.Liquid.Tags
  alias ArchiDep.CourseSite.Renderer.RenderOptions
  alias ArchiDep.Support.CourseSiteRendererTestTags.ShoutingPass
  alias ArchiDep.Support.CourseSiteRendererTestTags.SignaturePass

  describe "new/1" do
    test "builds the options of a build that asked for nothing in particular" do
      assert RenderOptions.new() == %RenderOptions{
               reveal_all_solutions: false,
               strict_variables: true,
               tags: Tags.default(),
               ast_passes: [],
               html_passes: [EmojiImages, ExternalLinks]
             }
    end

    test "builds fully configured options" do
      assert RenderOptions.new(
               reveal_all_solutions: true,
               strict_variables: false,
               tags: %{"link" => LinkTag},
               ast_passes: [ShoutingPass],
               html_passes: [SignaturePass]
             ) == %RenderOptions{
               reveal_all_solutions: true,
               strict_variables: false,
               tags: %{"link" => LinkTag},
               ast_passes: [ShoutingPass],
               html_passes: [SignaturePass]
             }
    end

    test "rejects a policy that is not a yes or a no" do
      assert_raise ArgumentError,
                   ":reveal_all_solutions must be a boolean, got: \"yes\"",
                   fn -> RenderOptions.new(reveal_all_solutions: "yes") end
    end

    test "rejects a tag table that is not one" do
      assert_raise ArgumentError,
                   "Tags must map tag names to modules, got: %{link: ArchiDep.CourseSite.Renderer.Liquid.LinkTag}",
                   fn -> RenderOptions.new(tags: %{link: LinkTag}) end
    end

    test "rejects passes that are not modules" do
      assert_raise ArgumentError,
                   ":ast_passes must be a list of modules, got: [\"shout\"]",
                   fn -> RenderOptions.new(ast_passes: ["shout"]) end
    end
  end
end
