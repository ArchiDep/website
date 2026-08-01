defmodule ArchiDep.CourseSite.Build.Site.OptionsTest do
  use ExUnit.Case, async: true

  import ArchiDep.Support.CourseSiteFactory, only: [build: 2]

  alias ArchiDep.CourseSite.Build.Site.Options
  alias ArchiDep.CourseSite.Layout.Minimal
  alias ArchiDep.CourseSite.Renderer.RenderOptions
  alias ArchiDep.CourseSite.SiteInfo
  alias ArchiDep.Support.CourseSiteTestLayout

  describe "new/1" do
    test "states what a build is, wrapping its pages in the bare layout by default" do
      urls = build(:url_context, version: nil)
      site = SiteInfo.new(version: "1.2.3", years: "2025-2026", years_short: "25-26")

      assert Options.new(urls: urls, site: site) == %Options{
               urls: urls,
               site: site,
               layout: Minimal,
               render_options: RenderOptions.new()
             }
    end

    test "takes the layout and the renderer's own options a build chooses" do
      urls = build(:url_context, version: nil)
      site = SiteInfo.new(version: "1.2.3", years: "2025-2026", years_short: "25-26")
      render_options = RenderOptions.new(strict_variables: false)

      assert Options.new(
               urls: urls,
               site: site,
               layout: CourseSiteTestLayout.Wrapper,
               render_options: render_options
             ) == %Options{
               urls: urls,
               site: site,
               layout: CourseSiteTestLayout.Wrapper,
               render_options: render_options
             }
    end

    test "refuses a URL context that is not one" do
      assert_raise ArgumentError,
                   "URL context must be a ArchiDep.CourseSite.Urls.UrlContext, got: :live",
                   fn ->
                     Options.new(
                       urls: :live,
                       site:
                         SiteInfo.new(version: "1.2.3", years: "2025-2026", years_short: "25-26")
                     )
                   end
    end

    test "refuses site info that is not a ArchiDep.CourseSite.SiteInfo" do
      assert_raise ArgumentError,
                   "Site info must be a ArchiDep.CourseSite.SiteInfo, got: \"1.2.3\"",
                   fn -> Options.new(urls: build(:url_context, version: nil), site: "1.2.3") end
    end

    test "refuses a layout that is not a module" do
      assert_raise ArgumentError,
                   "Layout must be a module, got: \"minimal\"",
                   fn ->
                     Options.new(
                       urls: build(:url_context, version: nil),
                       site:
                         SiteInfo.new(version: "1.2.3", years: "2025-2026", years_short: "25-26"),
                       layout: "minimal"
                     )
                   end
    end

    test "refuses render options that are not the renderer's" do
      assert_raise ArgumentError,
                   "Render options must be a ArchiDep.CourseSite.Renderer.RenderOptions, got: []",
                   fn ->
                     Options.new(
                       urls: build(:url_context, version: nil),
                       site:
                         SiteInfo.new(version: "1.2.3", years: "2025-2026", years_short: "25-26"),
                       render_options: []
                     )
                   end
    end
  end
end
