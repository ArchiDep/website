defmodule ArchiDep.CourseSite.RendererTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Renderer
  alias ArchiDep.CourseSite.Renderer.Liquid.Tags
  alias ArchiDep.CourseSite.Renderer.Page
  alias ArchiDep.CourseSite.Renderer.RenderError
  alias ArchiDep.CourseSite.Renderer.Slides
  alias ArchiDep.CourseSite.Renderer.Toc
  alias ArchiDep.CourseSite.Renderer.Toc.Entry
  alias ArchiDep.CourseSite.Urls.PageAssetManifest
  alias ArchiDep.Emoji
  alias ArchiDep.Support.CourseSiteFactory
  alias ArchiDep.Support.CourseSiteRendererTestTags
  alias ArchiDep.Support.CourseSiteRendererTestTags.FailingPass
  alias ArchiDep.Support.CourseSiteRendererTestTags.ShoutingPass
  alias ArchiDep.Support.CourseSiteRendererTestTags.SignaturePass

  @books ~s(<img class="emoji" src="/2026/assets/emoji/1f4da.svg" alt="📚" width="20" height="20" />)
  @coffee ~s(<img class="emoji" src="/2026/assets/emoji/2615.svg" alt="☕" width="20" height="20" />)
  @elsewhere ~s( target="_blank" rel="noopener noreferrer")

  describe "render_page/1" do
    test "renders a page in two pieces, resolving what it refers to" do
      {:ok, includes} =
        Renderer.compile_includes(%{"icons/photo.html" => ~s(<svg class="{{ include.class }}"/>)})

      assert render_page(
               """
               ---
               title: Platform-as-a-Service
               excerpt_separator: <!-- more -->
               ---

               Learn to deploy on [Render][render].

               <!-- more -->

               ## Deploying

               Read the [SFTP exercise]({% link _course/410-sftp-deployment/exercise.md %}) first,
               then {% include icons/photo.html class="size-6" %} look at {{ page.title }}.

               [render]: https://render.com
               """,
               includes: includes
             ) ==
               {:ok,
                %Page{
                  excerpt_html:
                    ~s(<p>Learn to deploy on <a href="https://render.com"#{@elsewhere}>) <>
                      ~s(Render</a>.</p>),
                  html:
                    ~s(<h2 id="deploying">Deploying<a href="#deploying" ) <>
                      ~s(aria-label="Link to heading 'Deploying'" data-heading-content="Deploying" ) <>
                      ~s(class="anchor"></a></h2>\n) <>
                      ~s(<p>Read the <a href="/2026/course/410-sftp-deployment/">SFTP exercise</a> first,\n) <>
                      ~s(then <svg class="size-6"/> look at Platform-as-a-Service.</p>),
                  toc: [%Entry{id: "deploying", level: 2, label_html: "Deploying"}]
                }}
    end

    test "navigates a page by its headings, the ones opening it included" do
      assert render_page("""
             ---
             excerpt_separator: <!-- more -->
             ---

             ## :books: What you will learn

             <!-- more -->

             ## Deploying

             ### Over SFTP
             """) ==
               {:ok,
                %Page{
                  excerpt_html:
                    ~s(<h2 id="what-you-will-learn">#{@books} What you will learn) <>
                      ~s(<a href="#what-you-will-learn" ) <>
                      ~s(aria-label="Link to heading 'What you will learn'" ) <>
                      ~s(data-heading-content="What you will learn" class="anchor"></a></h2>),
                  html:
                    ~s(<h2 id="deploying">Deploying<a href="#deploying" ) <>
                      ~s(aria-label="Link to heading 'Deploying'" data-heading-content="Deploying" ) <>
                      ~s(class="anchor"></a></h2>\n) <>
                      ~s(<h3 id="over-sftp">Over SFTP<a href="#over-sftp" ) <>
                      ~s(aria-label="Link to heading 'Over SFTP'" data-heading-content="Over SFTP" ) <>
                      ~s(class="anchor"></a></h3>),
                  toc: [
                    %Entry{
                      id: "what-you-will-learn",
                      level: 2,
                      label_html: "#{@books} What you will learn"
                    },
                    %Entry{
                      id: "deploying",
                      level: 2,
                      label_html: "Deploying",
                      entries: [%Entry{id: "over-sftp", level: 3, label_html: "Over SFTP"}]
                    }
                  ]
                }}
    end

    test "takes the opening of a page that declares no separator to be its first block" do
      assert render_page("An opening paragraph.\n\nThe rest of the page.\n") ==
               {:ok,
                %Page{
                  excerpt_html: "<p>An opening paragraph.</p>",
                  html: "<p>The rest of the page.</p>",
                  toc: []
                }}
    end

    test "gives a page of a single block nothing to introduce it" do
      assert render_page("The only paragraph.\n") ==
               {:ok, %Page{excerpt_html: nil, html: "<p>The only paragraph.</p>", toc: []}}
    end

    test "hands the home page over whole, its opening being the site's own" do
      assert render_page("An opening paragraph.\n\nThe rest of the page.\n", page: :home) ==
               {:ok,
                %Page{
                  excerpt_html: nil,
                  html: "<p>An opening paragraph.</p>\n<p>The rest of the page.</p>",
                  toc: []
                }}
    end

    test "runs the build's passes over both pieces of the page" do
      assert render_page(
               "An opening paragraph.\n\nThe rest of the page.\n",
               options:
                 CourseSiteFactory.build(:render_options,
                   tags: CourseSiteRendererTestTags.tags(),
                   ast_passes: [ShoutingPass],
                   html_passes: [SignaturePass]
                 )
             ) ==
               {:ok,
                %Page{
                  excerpt_html: "<p>AN OPENING PARAGRAPH.</p><!-- signed -->",
                  html: "<p>THE REST OF THE PAGE.</p><!-- signed -->",
                  toc: []
                }}
    end

    test "resolves the file the body of a block tag shows exactly once" do
      assert render_page(
               "{% prose %}\n<img src='images/cpu.png' class='w-full' />\n{% endprose %}\n",
               urls:
                 CourseSiteFactory.build(:url_context,
                   version: "2026",
                   base_path: "",
                   page_assets:
                     PageAssetManifest.new(%{
                       "/course/701-paas/images/cpu.png" => "cpu-1a2b3c.png"
                     })
                 )
             ) ==
               {:ok,
                %Page{
                  excerpt_html: nil,
                  html:
                    ~s(<div class="prose-plain">) <>
                      ~s(<img src='images/cpu-1a2b3c.png' class='w-full' /></div>),
                  toc: []
                }}
    end

    test "reports a page that declares an excerpt separator it never writes" do
      assert render_page("""
             ---
             excerpt_separator: <!-- more -->
             ---

             An opening paragraph.

             The rest of the page.
             """) ==
               {:error,
                [
                  RenderError.new(
                    {:missing_excerpt_separator, "<!-- more -->"},
                    "_course/701-paas/subject.md"
                  )
                ]}
    end

    test "reports a problem at the line of the file it is on, front matter included" do
      assert render_page("""
             ---
             title: Platform-as-a-Service
             ---

             An opening paragraph.

             {% boom %}
             """) == {:error, [boom_error(%{line: 7, column: 1})]}
    end

    test "reports everything wrong with a page, whichever stage found it" do
      assert render_page(
               "{% boom %}\n\nAn opening paragraph.\n\nThe rest of the page.\n",
               options:
                 CourseSiteFactory.build(:render_options,
                   tags: CourseSiteRendererTestTags.tags(),
                   ast_passes: [FailingPass]
                 )
             ) ==
               {:error,
                [
                  boom_error(%{line: 1, column: 1}),
                  pass_error(),
                  pass_error()
                ]}
    end

    test "reports a page that does not parse" do
      assert render_page("{% nope %}\n") ==
               {:error,
                [
                  RenderError.new(
                    {:liquid, "Unexpected tag 'nope'"},
                    "_course/701-paas/subject.md",
                    %{line: 1, column: 1}
                  )
                ]}
    end

    test "expands the Liquid a link reference definition is written with, in the page and in a fragment of it" do
      assert render_page("""
             Read the [command line subject][cli].

             {% prose kind: note %}
             And [the same subject][cli] from inside a tag.
             {% endprose %}

             [cli]: {% link _course/101-command-line/subject.md %}
             """) ==
               {:ok,
                %Page{
                  excerpt_html:
                    ~s(<p>Read the <a href="/2026/course/101-command-line/">command line subject</a>.</p>),
                  html:
                    ~s(<div class="prose-note"><p>And <a href="/2026/course/101-command-line/">) <>
                      ~s(the same subject</a> from inside a tag.</p></div>),
                  toc: []
                }}
    end

    test "reports what is wrong with a link reference definition once, where it is written" do
      assert render_page("""
             Read the [broken link][broken].

             [broken]: {% boom %}
             """) == {:error, [boom_error(%{line: 3, column: 11})]}
    end
  end

  describe "render_slides/1" do
    test "expands the Liquid of a deck and leaves it as Markdown" do
      assert render_slides("""
             ---
             title: Command Line
             ---

             # Command line

             See the [exercise]({% link _course/410-sftp-deployment/exercise.md %}).
             """) ==
               {:ok,
                %Slides{
                  markdown:
                    "# Command line\n\nSee the [exercise](/2026/course/410-sftp-deployment/).\n"
                }}
    end

    test "resolves a reference link of every slide rather than of the last one" do
      assert render_slides("""
             # First slide

             See [Ada][ada].

             ---

             ## Second slide

             Also see [Ada][ada].

             [ada]: https://example.com/ada
             """) ==
               {:ok,
                %Slides{
                  markdown: """
                  # First slide

                  See [Ada](https://example.com/ada).

                  ---

                  ## Second slide

                  Also see [Ada](https://example.com/ada).

                  [ada]: https://example.com/ada
                  """
                }}
    end

    test "resolves what a deck shows and draws what it celebrates with" do
      assert render_slides(
               """
               # Cloud computing

               <img class='w-3/4' src='../images/client-server.jpg' />

               ---

               ## Hosting

               ![Shared hosting](../images/shared-hosting.png)

               Carelessness and coffee spills <div class="emoji-container">:coffee:</div>
               """,
               page: {:document, DocumentRef.new(401, "cloud-computing", :slides)},
               source_path: "_course/401-cloud-computing/slides.md",
               urls:
                 CourseSiteFactory.build(:url_context,
                   version: "2026",
                   base_path: "",
                   page_assets:
                     PageAssetManifest.new(%{
                       "/course/401-cloud-computing/images/client-server.jpg" =>
                         "client-server-1a2b3c.jpg",
                       "/course/401-cloud-computing/images/shared-hosting.png" =>
                         "shared-hosting-2b3c4d.png"
                     })
                 )
             ) ==
               {:ok,
                %Slides{
                  markdown: """
                  # Cloud computing

                  <img class='w-3/4' src='../images/client-server-1a2b3c.jpg' />

                  ---

                  ## Hosting

                  ![Shared hosting](../images/shared-hosting-2b3c4d.png)

                  Carelessness and coffee spills <div class="emoji-container">#{@coffee}</div>
                  """
                }}
    end

    test "leaves the picture of an emoji it just drew alone" do
      assert render_slides("A drink :coffee: and a picture ![Zone](images/zone.png)\n",
               page: {:document, DocumentRef.new(507, "dns", :slides)},
               source_path: "_course/507-dns/slides/slides.md",
               urls:
                 CourseSiteFactory.build(:url_context,
                   version: "2026",
                   base_path: "",
                   page_assets:
                     PageAssetManifest.new(%{
                       "/course/507-dns/slides/images/zone.png" => "zone-3c4d5e.png"
                     })
                 )
             ) ==
               {:ok,
                %Slides{
                  markdown: "A drink #{@coffee} and a picture ![Zone](images/zone-3c4d5e.png)\n"
                }}
    end

    test "reports a problem in a deck" do
      assert render_slides("# Slide\n\n{% boom %}\n") ==
               {:error, [boom_error(%{line: 3, column: 1})]}
    end

    test "reports the file a deck shows that the build does not have, once for the deck" do
      assert render_slides(
               "<img src='images/gone.png' />\n\n---\n\n![Gone](images/gone.png)\n",
               page: {:document, DocumentRef.new(201, "git", :slides)},
               source_path: "_course/201-git/slides/slides.md"
             ) ==
               {:error,
                [
                  RenderError.new(
                    {:url,
                     {:unknown_page_asset, {:document, DocumentRef.new(201, "git", :slides)},
                      "images/gone.png", "/course/201-git/slides/images/gone.png"}},
                    "_course/201-git/slides/slides.md"
                  )
                ]}
    end
  end

  describe "compile_includes/1" do
    test "parses the partials of a build" do
      source = ~s(<svg class="{{ include.class }}"/>)
      {:ok, template} = Solid.parse(source, tags: Tags.default())

      assert Renderer.compile_includes(%{"icons/photo.html" => source}) ==
               {:ok, %{"icons/photo.html" => template}}
    end

    test "reports a partial that does not parse, saying which one it is" do
      assert Renderer.compile_includes(%{"icons/broken.html" => "{% nope %}"}) ==
               {:error,
                [
                  RenderError.new(
                    {:liquid, "Unexpected tag 'nope'"},
                    "icons/broken.html",
                    %{line: 1, column: 1}
                  )
                ]}
    end
  end

  describe "headings/1" do
    test "identifies the headings of a page, the ones opening it included" do
      assert headings("""
             ---
             excerpt_separator: <!-- more -->
             ---

             ## :books: What you will learn

             <!-- more -->

             ## Deploying

             ### Over SFTP
             """) == {:ok, ["what-you-will-learn", "deploying", "over-sftp"]}
    end

    test "identifies the headings a tag writes as well as the ones the page does" do
      assert headings("""
             ## Deploying

             {% prose kind: note %}
             ### A word of warning
             {% endprose %}
             """) == {:ok, ["deploying", "a-word-of-warning"]}
    end

    test "tells apart the identifiers of a heading a page writes twice" do
      assert headings("Opening.\n\n## Troubleshooting\n\nProse.\n\n## Troubleshooting\n") ==
               {:ok, ["troubleshooting", "troubleshooting-1"]}
    end

    test "gives a page that writes no heading nothing to link to" do
      assert headings("A page of prose.\n") == {:ok, []}
    end

    test "reports what is wrong with a page it cannot render" do
      assert headings("{% boom %}\n") == {:error, [boom_error(%{line: 1, column: 1})]}
    end

    property "identifies the same headings a page rendered with its passes does" do
      check all(written <- headings_generator()) do
        context = context(document(written), [])

        {:ok, %Page{toc: toc}} = Renderer.render_page(context)

        assert Renderer.headings(context) == {:ok, Toc.identifiers(toc)}
      end
    end
  end

  # A page of headings alone, each of a level of its own and some of them
  # decorated, which is what the identifiers depend on: the shortcode is moved
  # out of the text before it is slugged, and a heading written twice is
  # numbered according to what came before it.
  defp headings_generator do
    gen all(
          words <- list_of(member_of(~w(deploying troubleshooting permissions)), min_length: 1),
          levels <- list_of(integer(1..6), length: length(words)),
          shortcodes <-
            list_of(one_of([constant(nil), member_of(Emoji.names())]), length: length(words))
        ) do
      Enum.zip([levels, shortcodes, words])
    end
  end

  defp document(written),
    do:
      Enum.map_join(written, "\n\n", fn {level, shortcode, word} ->
        "#{String.duplicate("#", level)} #{decoration(shortcode)}#{word}"
      end) <> "\n"

  defp decoration(nil), do: ""
  defp decoration(shortcode), do: ":#{shortcode}: "

  defp boom_error(loc),
    do:
      RenderError.new(
        {:invalid_tag, "boom", "this tag always fails"},
        "_course/701-paas/subject.md",
        loc
      )

  defp pass_error,
    do:
      RenderError.new(
        {:invalid_tag, "pass", "this pass always fails"},
        "_course/701-paas/subject.md"
      )

  defp headings(text, attrs \\ []), do: Renderer.headings(context(text, attrs))

  defp render_page(text, attrs \\ []), do: Renderer.render_page(context(text, attrs))

  defp render_slides(text, attrs \\ []), do: Renderer.render_slides(context(text, attrs))

  defp context(text, attrs) do
    CourseSiteFactory.build(
      :render_context,
      Keyword.merge(
        [
          source: CourseSiteFactory.build(:source, text: text),
          source_path: "_course/701-paas/subject.md",
          page: {:document, DocumentRef.new(701, "paas", :subject)},
          urls: CourseSiteFactory.build(:url_context, version: "2026", base_path: ""),
          options:
            CourseSiteFactory.build(:render_options, tags: CourseSiteRendererTestTags.tags())
        ],
        attrs
      )
    )
  end
end
