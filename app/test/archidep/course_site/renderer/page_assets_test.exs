defmodule ArchiDep.CourseSite.Renderer.PageAssetsTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Renderer.Markdown
  alias ArchiDep.CourseSite.Renderer.RenderError
  alias ArchiDep.CourseSite.Urls.PageAssetManifest
  alias ArchiDep.Support.CourseSiteFactory

  @source_path "_course/507-dns/subject.md"
  @page {:document, DocumentRef.new(507, "dns", :subject)}

  describe "run/2" do
    test "resolves the image a page shows" do
      assert run("![A zone file](images/zone.png)\n", %{
               "/course/507-dns/images/zone.png" => "zone-1a2b3c.png"
             }) == {~s(<p><img src="images/zone-1a2b3c.png" alt="A zone file" /></p>), []}
    end

    test "resolves the file a page links to" do
      assert run("Read the [handout](handouts/dns.pdf) first.\n", %{
               "/course/507-dns/handouts/dns.pdf" => "dns-2b3c4d.pdf"
             }) == {~s(<p>Read the <a href="handouts/dns-2b3c4d.pdf">handout</a> first.</p>), []}
    end

    test "resolves the image written in a block of raw HTML" do
      assert run("<div class='w80'><img src='images/dig.jpg' /></div>\n", %{
               "/course/507-dns/images/dig.jpg" => "dig-3c4d5e.jpg"
             }) == {"<div class='w80'><img src='images/dig-3c4d5e.jpg' /></div>", []}
    end

    test "resolves the image written in raw HTML in the middle of a sentence" do
      assert run("Look <img src='images/dig.jpg' /> at that.\n", %{
               "/course/507-dns/images/dig.jpg" => "dig-3c4d5e.jpg"
             }) == {"<p>Look <img src='images/dig-3c4d5e.jpg' /> at that.</p>", []}
    end

    test "leaves the pages and sites a page refers to alone" do
      assert run("See [Cloudflare](https://cloudflare.com) and [above](#top).\n", %{}) ==
               {~s(<p>See <a href="https://cloudflare.com">Cloudflare</a> and ) <>
                  ~s(<a href="#top">above</a>.</p>), []}
    end

    test "leaves a link to a page written relatively alone, saying nothing about it" do
      assert run(
               "Do the [previous exercise](dns-configuration.md) and [the CLI](../cli/).\n",
               %{}
             ) ==
               {~s(<p>Do the <a href="dns-configuration.md">previous exercise</a> and ) <>
                  ~s(<a href="../cli/">the CLI</a>.</p>), []}
    end

    test "resolves the file a page both shows and links to, reporting it once when missing" do
      assert run("[![Diagram](images/gone.png)](images/gone.png)\n", %{}) ==
               {~s(<p><a href="images/gone.png"><img src="images/gone.png" alt="Diagram" /></a></p>),
                [
                  RenderError.new(
                    {:url,
                     {:unknown_page_asset, @page, "images/gone.png",
                      "/course/507-dns/images/gone.png"}},
                    @source_path
                  )
                ]}
    end

    test "reports the file a page refers to that the build does not have, once for the page" do
      assert run("![One](images/typo.png)\n\n![Two](images/typo.png)\n", %{}) ==
               {~s(<p><img src="images/typo.png" alt="One" /></p>\n) <>
                  ~s(<p><img src="images/typo.png" alt="Two" /></p>),
                [
                  RenderError.new(
                    {:url,
                     {:unknown_page_asset, @page, "images/typo.png",
                      "/course/507-dns/images/typo.png"}},
                    @source_path
                  )
                ]}
    end
  end

  defp run(markdown, page_assets) do
    Markdown.to_html(markdown, context(page_assets))
  end

  defp context(page_assets) do
    CourseSiteFactory.build(:render_context,
      source_path: @source_path,
      page: @page,
      urls:
        CourseSiteFactory.build(:url_context,
          page_assets: PageAssetManifest.new(page_assets)
        )
    )
  end
end
