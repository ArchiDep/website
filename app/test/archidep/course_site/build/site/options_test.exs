defmodule ArchiDep.CourseSite.Build.Site.OptionsTest do
  use ExUnit.Case, async: true

  import ArchiDep.Support.CourseSiteFactory, only: [build: 2]

  alias ArchiDep.CourseSite.Build.Site.Options
  alias ArchiDep.CourseSite.Layout.Chrome
  alias ArchiDep.CourseSite.Renderer.RenderOptions
  alias ArchiDep.CourseSite.SiteInfo
  alias ArchiDep.Support.CourseSiteTestLayout

  describe "new/1" do
    test "states what a build is, wrapping its pages in the site's own chrome and pointing llms.txt at the main site by default" do
      urls = build(:url_context, version: nil)
      site = SiteInfo.new(version: "1.2.3", years: "2025-2026", years_short: "25-26")

      assert Options.new(urls: urls, site: site) == %Options{
               urls: urls,
               site: site,
               layout: Chrome,
               render_options: RenderOptions.new(),
               llms_site_url: "https://archidep.ch"
             }
    end

    test "takes the layout, the renderer's own options and the site llms.txt links to a build chooses" do
      urls = build(:url_context, version: nil)
      site = SiteInfo.new(version: "1.2.3", years: "2025-2026", years_short: "25-26")
      render_options = RenderOptions.new(strict_variables: false)

      assert Options.new(
               urls: urls,
               site: site,
               layout: CourseSiteTestLayout.Wrapper,
               render_options: render_options,
               llms_site_url: "http://localhost:4000"
             ) == %Options{
               urls: urls,
               site: site,
               layout: CourseSiteTestLayout.Wrapper,
               render_options: render_options,
               llms_site_url: "http://localhost:4000"
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

    test "refuses a site for llms.txt that is not an absolute URL with no trailing slash" do
      for url <- ["archidep.ch", "/website", "https://archidep.ch/", :archidep] do
        assert_raise ArgumentError,
                     "The site llms.txt links to must be an absolute URL with no trailing slash, got: #{inspect(url)}",
                     fn ->
                       Options.new(
                         urls: build(:url_context, version: nil),
                         site:
                           SiteInfo.new(
                             version: "1.2.3",
                             years: "2025-2026",
                             years_short: "25-26"
                           ),
                         llms_site_url: url
                       )
                     end
      end
    end
  end
end
