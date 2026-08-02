defmodule ArchiDepWeb.Helpers.CourseMaterialHelpersTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.HeadingRef
  alias ArchiDep.CourseSite.Structure.Chapter
  alias ArchiDep.CourseSite.Structure.Cheatsheet
  alias ArchiDep.CourseSite.Urls.AssetManifest
  alias ArchiDep.CourseSite.Urls.PageAssetManifest
  alias ArchiDep.CourseSite.Urls.PdfManifest
  alias ArchiDep.CourseSite.Urls.UrlContext
  alias ArchiDep.CourseSite.Urls.UrlError
  alias ArchiDepWeb.Helpers.CourseMaterialHelpers

  describe "course_url/1" do
    test "addresses a chapter of the course material" do
      chapter =
        Chapter.new(
          DocumentRef.new(402, "run-virtual-server", :exercise),
          "Run your own virtual server"
        )

      assert CourseMaterialHelpers.course_url(chapter) == "/1955/course/402-run-virtual-server/"
    end

    test "addresses a cheatsheet of the course material" do
      cheatsheet = Cheatsheet.new("sysadmin", "System Administration Cheatsheet")

      assert CourseMaterialHelpers.course_url(cheatsheet) == "/1955/cheatsheets/sysadmin/"
    end

    test "addresses a heading of a chapter of the course material" do
      heading =
        HeadingRef.new({:document, DocumentRef.new(403, "linux", :subject)}, "install-linux")

      assert CourseMaterialHelpers.course_url(heading) == "/1955/course/403-linux/#install-linux"
    end

    test "addresses a heading of a cheatsheet of the course material" do
      heading = HeadingRef.new({:cheatsheet, "git"}, "how-do-i-commit")

      assert CourseMaterialHelpers.course_url(heading) == "/1955/cheatsheets/git/#how-do-i-commit"
    end

    test "passes a reference of the course material site through" do
      assert CourseMaterialHelpers.course_url(:home) == "/"
    end

    test "refuses a reference the course material site has no URL for" do
      assert_raise UrlError, ~s[{:nonsense, "402"} is not a valid reference], fn ->
        CourseMaterialHelpers.course_url({:nonsense, "402"})
      end
    end
  end

  describe "url_context/0" do
    test "addresses the current edition of the course material at the root of the site" do
      assert CourseMaterialHelpers.url_context() == %UrlContext{
               mode: :live,
               base_path: "",
               version: "1955",
               build_id: "app",
               absolute_base_url: nil,
               live_site_url: nil,
               assets: AssetManifest.new(%{}),
               page_assets: PageAssetManifest.new(%{}),
               pdfs: PdfManifest.new(:site, %{})
             }
    end
  end
end
