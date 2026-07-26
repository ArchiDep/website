defmodule ArchiDep.CourseSite.Renderer.AssetReferencesTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Renderer.AssetReferences
  alias ArchiDep.CourseSite.Renderer.RenderError
  alias ArchiDep.CourseSite.Urls.PageAssetManifest
  alias ArchiDep.CourseSite.Urls.UrlContext
  alias ArchiDep.Support.CourseSiteFactory

  describe "rewrite/3 over the raw HTML of a page" do
    test "resolves the image of a page" do
      assert rewrite(~s(<img src="images/cli.jpg" alt="A shell" />), :html,
               page: {:document, DocumentRef.new(101, "command-line", :subject)},
               page_assets: %{"/course/101-command-line/images/cli.jpg" => "cli-9f8e7d.jpg"}
             ) == {~s(<img src="images/cli-9f8e7d.jpg" alt="A shell" />), []}
    end

    test "leaves the code a page shows as markup alone" do
      assert rewrite(
               ~s(<pre><code>&lt;img src="images/cli.jpg"&gt;</code></pre>),
               :html,
               page: {:document, DocumentRef.new(101, "command-line", :subject)},
               page_assets: %{"/course/101-command-line/images/cli.jpg" => "cli-9f8e7d.jpg"}
             ) == {~s(<pre><code>&lt;img src="images/cli.jpg"&gt;</code></pre>), []}
    end
  end

  describe "rewrite/3 over the Markdown of a deck" do
    test "resolves the image a deck writes in Markdown" do
      assert rewrite("![The zone](images/dns-zone.png)\n", :markdown,
               page: {:document, DocumentRef.new(507, "dns", :slides)},
               page_assets: %{
                 "/course/507-dns/slides/images/dns-zone.png" => "dns-zone-1a2b3c.png"
               }
             ) == {"![The zone](images/dns-zone-1a2b3c.png)\n", []}
    end

    test "resolves the image a deck written at the root of its chapter reaches one directory up" do
      assert rewrite("<img class='w-3/4' src='../images/client-server.jpg' />\n", :markdown,
               page: {:document, DocumentRef.new(401, "cloud-computing", :slides)},
               page_assets: %{
                 "/course/401-cloud-computing/images/client-server.jpg" =>
                   "client-server-2b3c4d.jpg"
               }
             ) == {"<img class='w-3/4' src='../images/client-server-2b3c4d.jpg' />\n", []}
    end

    test "resolves an image whose tag is never closed" do
      assert rewrite(~s(<img height="150px" src="./images/fat-container.png">\n), :markdown,
               page: {:document, DocumentRef.new(804, "docker-compose", :slides)},
               page_assets: %{
                 "/course/804-docker-compose/slides/images/fat-container.png" =>
                   "fat-container-3c4d5e.png"
               }
             ) == {~s(<img height="150px" src="./images/fat-container-3c4d5e.png">\n), []}
    end

    test "resolves the file a deck links to as well as the image it shows" do
      assert rewrite(
               "<a href='../images/timeline.svg'><img src='../images/timeline.svg' /></a>\n",
               :markdown,
               page: {:document, DocumentRef.new(403, "linux", :slides)},
               page_assets: %{"/course/403-linux/images/timeline.svg" => "timeline-4d5e6f.svg"}
             ) ==
               {"<a href='../images/timeline-4d5e6f.svg'>" <>
                  "<img src='../images/timeline-4d5e6f.svg' /></a>\n", []}
    end

    test "resolves a reference the Liquid stage already resolved" do
      assert rewrite(~s(<img src="images/engine-5e6f7a.jpg" />\n), :markdown,
               page: {:document, DocumentRef.new(101, "command-line", :slides)},
               page_assets: %{
                 "/course/101-command-line/slides/images/engine.jpg" => "engine-5e6f7a.jpg"
               }
             ) == {~s(<img src="images/engine-5e6f7a.jpg" />\n), []}
    end

    test "leaves the pages, sites and headings a deck refers to alone" do
      markdown = """
      See the [exercise](/2026/course/410-sftp-deployment/) and
      [Render](https://render.com), then [go back](#top) or
      <a href="mailto:teacher@example.com">ask</a>.
      """

      assert rewrite(markdown, :markdown,
               page: {:document, DocumentRef.new(701, "paas", :slides)},
               page_assets: %{}
             ) == {markdown, []}
    end

    test "leaves the markup a deck shows in a fenced code block alone" do
      markdown = "```html\n<img src=\"images/example.png\" />\n```\n"

      assert rewrite(markdown, :markdown,
               page: {:document, DocumentRef.new(509, "reverse-proxy", :slides)},
               page_assets: %{
                 "/course/509-reverse-proxy/slides/images/example.png" => "example-6f7a8b.png"
               }
             ) == {markdown, []}
    end

    test "leaves a link whose file the build does not have alone, saying nothing about it" do
      markdown = "<a href='../handouts/gone.pdf'>Handout</a> and [another](handouts/gone.pdf)\n"

      assert rewrite(markdown, :markdown,
               page: {:document, DocumentRef.new(513, "tls", :slides)},
               page_assets: %{}
             ) == {markdown, []}
    end

    test "reports the file a deck refers to that the build does not have, once for the deck" do
      markdown = "![One](images/typo.png)\n\n---\n\n<img src='images/typo.png' />\n"

      assert rewrite(markdown, :markdown,
               page: {:document, DocumentRef.new(201, "git", :slides)},
               page_assets: %{}
             ) ==
               {markdown,
                [
                  RenderError.new(
                    {:url,
                     {:unknown_page_asset, {:document, DocumentRef.new(201, "git", :slides)},
                      "images/typo.png", "/course/201-git/slides/images/typo.png"}},
                    "_course/201-git/slides/slides.md"
                  )
                ]}
    end
  end

  describe "rewrite/3 invariants" do
    property "resolving what a deck refers to again is resolving it once" do
      page_assets =
        PageAssetManifest.new(%{
          "/course/408-unix-networking/slides/images/ip.png" => "ip-7a8b9c.png"
        })

      deck = "![An address](./images/ip.png)\n\n<img src='images/ip.png' />\n"

      check all %UrlContext{} = generated <- CourseSiteFactory.url_context_generator() do
        context =
          CourseSiteFactory.build(:render_context,
            source_path: "_course/408-unix-networking/slides/slides.md",
            page: {:document, DocumentRef.new(408, "unix-networking", :slides)},
            urls: %{generated | page_assets: page_assets}
          )

        {once, []} = AssetReferences.rewrite(deck, :markdown, context)

        assert AssetReferences.rewrite(once, :markdown, context) == {once, []}
      end
    end
  end

  defp rewrite(text, syntax, opts) do
    {page, opts} = Keyword.pop!(opts, :page)
    {page_assets, []} = Keyword.pop!(opts, :page_assets)

    AssetReferences.rewrite(
      text,
      syntax,
      CourseSiteFactory.build(:render_context,
        source_path: source_path(page),
        page: page,
        urls:
          CourseSiteFactory.build(:url_context,
            page_assets: PageAssetManifest.new(page_assets)
          )
      )
    )
  end

  defp source_path({:document, %DocumentRef{type: :slides} = document}),
    do: "_course/#{DocumentRef.dir(document)}/slides/slides.md"

  defp source_path({:document, %DocumentRef{type: type} = document}),
    do: "_course/#{DocumentRef.dir(document)}/#{type}.md"
end
