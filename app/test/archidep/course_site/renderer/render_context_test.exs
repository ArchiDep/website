defmodule ArchiDep.CourseSite.Renderer.RenderContextTest do
  use ExUnit.Case, async: true

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Renderer
  alias ArchiDep.CourseSite.Renderer.RenderContext
  alias ArchiDep.CourseSite.Renderer.RenderOptions
  alias ArchiDep.CourseSite.Renderer.Source
  alias ArchiDep.CourseSite.Urls.UrlContext

  describe "new/1" do
    test "builds the context of a document from what identifies it" do
      {:ok, source} = Source.parse("Prose.\n")
      urls = UrlContext.new(mode: :live, build_id: "3f2a1b", version: "2026")
      page = {:document, DocumentRef.new(507, "dns", :subject)}

      assert RenderContext.new(
               source: source,
               source_path: "_course/507-dns/subject.md",
               urls: urls,
               page: page
             ) == %RenderContext{
               source: source,
               source_path: "_course/507-dns/subject.md",
               urls: urls,
               page: page,
               page_variables: %{},
               includes: %{},
               options: RenderOptions.new(),
               solutions: :revealed
             }
    end

    test "builds a fully configured context" do
      {:ok, source} = Source.parse("Prose.\n")
      {:ok, includes} = Renderer.compile_includes(%{"icons/photo.html" => "<svg/>"})

      urls =
        UrlContext.new(
          mode: :archive,
          build_id: "9c8b7a",
          version: "2025",
          live_site_url: "https://archidep.example.com"
        )

      options = RenderOptions.new(strict_variables: false)

      assert RenderContext.new(
               source: source,
               source_path: "_cheatsheets/git/cheatsheet.md",
               urls: urls,
               page: {:cheatsheet, "git"},
               page_variables: %{"num" => 507},
               includes: includes,
               options: options,
               solutions: :hidden
             ) == %RenderContext{
               source: source,
               source_path: "_cheatsheets/git/cheatsheet.md",
               urls: urls,
               page: {:cheatsheet, "git"},
               page_variables: %{"num" => 507},
               includes: includes,
               options: options,
               solutions: :hidden
             }
    end

    test "rejects a page that is not a page of the site" do
      assert_raise ArgumentError,
                   "Page must be a page reference, got: {:document, \"507-dns\"}",
                   fn -> new(page: {:document, "507-dns"}) end
    end

    test "rejects a source that was never taken apart" do
      assert_raise ArgumentError,
                   "Source must be a ArchiDep.CourseSite.Renderer.Source, got: \"Prose.\\n\"",
                   fn -> new(source: "Prose.\n") end
    end

    test "rejects a source path that names nothing" do
      assert_raise ArgumentError,
                   "Source path must be a non-empty string, got: \"\"",
                   fn -> new(source_path: "") end
    end

    test "rejects page variables a template could not name" do
      assert_raise ArgumentError,
                   "Page variables must be keyed by strings, got: %{num: 507}",
                   fn -> new(page_variables: %{num: 507}) end
    end

    test "rejects an answer to whether the page shows its solutions that is neither" do
      assert_raise ArgumentError,
                   "Solutions must be :revealed or :hidden, got: :maybe",
                   fn -> new(solutions: :maybe) end
    end

    test "rejects partials that were never parsed" do
      assert_raise ArgumentError,
                   "Includes must map paths to parsed templates, got: %{\"icons/photo.html\" => \"<svg/>\"}",
                   fn -> new(includes: %{"icons/photo.html" => "<svg/>"}) end
    end
  end

  describe "page_variables/1" do
    test "layers the build's own values over the front matter" do
      {:ok, source} = Source.parse("---\ntitle: DNS\nnum: 0\n---\nProse.\n")

      context = new(source: source, page_variables: %{"num" => 507})

      assert RenderContext.page_variables(context) == %{"title" => "DNS", "num" => 507}
    end
  end

  defp new(attrs) do
    {:ok, source} = Source.parse("Prose.\n")

    RenderContext.new(
      Keyword.merge(
        [
          source: source,
          source_path: "_course/507-dns/subject.md",
          urls: UrlContext.new(mode: :live, build_id: "3f2a1b"),
          page: {:document, DocumentRef.new(507, "dns", :subject)}
        ],
        attrs
      )
    )
  end
end
