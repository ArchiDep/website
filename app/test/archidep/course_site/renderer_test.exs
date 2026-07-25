defmodule ArchiDep.CourseSite.RendererTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Renderer
  alias ArchiDep.CourseSite.Renderer.Liquid.Tags
  alias ArchiDep.CourseSite.Renderer.Page
  alias ArchiDep.CourseSite.Renderer.RenderError
  alias ArchiDep.CourseSite.Renderer.Slides
  alias ArchiDep.Support.CourseSiteFactory
  alias ArchiDep.Support.CourseSiteRendererTestTags
  alias ArchiDep.Support.CourseSiteRendererTestTags.FailingPass
  alias ArchiDep.Support.CourseSiteRendererTestTags.ShoutingPass
  alias ArchiDep.Support.CourseSiteRendererTestTags.SignaturePass

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
                    ~s(<p>Learn to deploy on <a href="https://render.com">Render</a>.</p>),
                  html:
                    ~s(<h2 id="deploying">Deploying<a href="#deploying" ) <>
                      ~s(aria-label="Link to heading 'Deploying'" data-heading-content="Deploying" ) <>
                      ~s(class="anchor"></a></h2>\n) <>
                      ~s(<p>Read the <a href="/2026/course/410-sftp-deployment/">SFTP exercise</a> first,\n) <>
                      ~s(then <svg class="size-6"/> look at Platform-as-a-Service.</p>)
                }}
    end

    test "takes the opening of a page that declares no separator to be its first block" do
      assert render_page("An opening paragraph.\n\nThe rest of the page.\n") ==
               {:ok,
                %Page{
                  excerpt_html: "<p>An opening paragraph.</p>",
                  html: "<p>The rest of the page.</p>"
                }}
    end

    test "gives a page of a single block nothing to introduce it" do
      assert render_page("The only paragraph.\n") ==
               {:ok, %Page{excerpt_html: nil, html: "<p>The only paragraph.</p>"}}
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
                  html: "<p>THE REST OF THE PAGE.</p><!-- signed -->"
                }}
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

    test "reports a problem in a deck" do
      assert render_slides("# Slide\n\n{% boom %}\n") ==
               {:error, [boom_error(%{line: 3, column: 1})]}
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
