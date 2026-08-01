defmodule ArchiDep.CourseSite.Layout.ChromeTest do
  use ExUnit.Case, async: true

  import ArchiDep.Support.CourseSiteFactory, only: [build: 2]

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Layout.Chrome
  alias ArchiDep.CourseSite.Layout.Chrome.Assigns
  alias ArchiDep.CourseSite.Layout.Chrome.Deck
  alias ArchiDep.CourseSite.Layout.Chrome.Document
  alias ArchiDep.CourseSite.Layout.Chrome.Html
  alias ArchiDep.CourseSite.Layout.LayoutContext
  alias ArchiDep.CourseSite.Renderer.Page
  alias ArchiDep.CourseSite.Renderer.PageMetadata
  alias ArchiDep.CourseSite.Renderer.Slides
  alias ArchiDep.CourseSite.Renderer.Toc.Entry
  alias ArchiDep.CourseSite.SiteInfo
  alias ArchiDep.CourseSite.Structure
  alias ArchiDep.CourseSite.Structure.Chapter
  alias ArchiDep.CourseSite.Structure.Cheatsheet
  alias ArchiDep.CourseSite.Structure.Section
  alias ArchiDep.CourseSite.Urls.AssetManifest
  alias ArchiDep.Emoji

  @dns DocumentRef.new(507, "dns", :subject)
  @dns_deck DocumentRef.new(507, "dns", :slides)
  @todolist DocumentRef.new(205, "php-todolist", :exercise)

  @assets [
    "/assets/theme/theme.css",
    "/assets/course/course.js",
    "/assets/course/slides.css",
    "/assets/theme/slides.css",
    "/assets/course/slides.js",
    "/assets/course/slides-mermaid.js"
  ]

  # What this layout decides, over and above what its parts draw, is two things:
  # which of the two documents a page becomes, and what happens when a reference
  # does not resolve. Each part's own markup is pinned by that part's test, so
  # the expectation here is built by calling the part the dispatch should have
  # chosen — which is the whole of what is being asserted.
  describe "document/1" do
    for {what, page} <- [
          {"a chapter", {:document, DocumentRef.new(507, "dns", :subject)}},
          {"an exercise", {:document, DocumentRef.new(205, "php-todolist", :exercise)}},
          {"a cheatsheet", {:cheatsheet, "git"}},
          {"the page introducing the course", :home}
        ] do
      test "draws #{what} as a page of the site" do
        context = context(page: unquote(Macro.escape(page)))

        assert Chrome.document(context) == {:ok, expected_page(context)}
      end
    end

    test "draws a deck as its own document rather than as a page of the site" do
      context = context(page: {:document, @dns_deck}, content: %Slides{markdown: "# DNS\n"})

      assert Chrome.document(context) == {:ok, expected_deck(context)}
    end

    test "reports every reference it could not resolve rather than drawing half a page" do
      assert Chrome.document(context(assets: [])) ==
               {:error, missing(page_assets() ++ emoji_assets())}
    end
  end

  defp expected_page(context) do
    {:ok, page} = Assigns.build(context)

    %{page: page} |> Document.document() |> Html.render()
  end

  defp expected_deck(context) do
    {:ok, page} = Assigns.build(context)

    %{page: page} |> Deck.deck() |> Html.render()
  end

  defp missing(paths),
    do: paths |> Enum.uniq() |> Enum.sort() |> Enum.map(&{:unknown_asset, &1})

  defp page_assets, do: ["/assets/theme/theme.css", "/assets/course/course.js"]

  defp context(overrides) do
    page = Keyword.get(overrides, :page, {:document, @dns})

    LayoutContext.new(
      page: page,
      source_path: source_path(page),
      content: Keyword.get(overrides, :content, page_content()),
      metadata: metadata(),
      entry: entry(page),
      section: section(page),
      front_matter: %{"title" => "Domain Name System (DNS)"},
      structure: structure(),
      statuses: %{500 => :due, 507 => :due},
      urls:
        build(:url_context,
          base_path: "",
          version: nil,
          assets: AssetManifest.new(Map.new(assets(overrides), &{&1, &1}))
        ),
      site:
        SiteInfo.new(
          version: "1.2.3",
          git_branch: "main",
          git_revision: "abc123",
          years: "2025-2026",
          years_short: "25-26"
        )
    )
  end

  defp assets(overrides), do: Keyword.get(overrides, :assets, @assets ++ emoji_assets())

  defp emoji_assets,
    do:
      Enum.map(
        ~w(book memo trophy hammer_and_wrench clapper scroll exclamation question space_invader checkered_flag classical_building boom),
        &Emoji.asset_path(Emoji.fetch!(&1))
      )

  defp page_content,
    do: %Page{
      html: "<h2 id=\"what\">What</h2>",
      excerpt_html: "<p>A name.</p>",
      toc: [%Entry{id: "what", level: 2, label_html: "What", entries: []}]
    }

  defp metadata,
    do: %PageMetadata{
      title: "Domain Name System (DNS) · ArchiDep",
      page_title: "Domain Name System (DNS)",
      description: "A name.",
      canonical_url: nil
    }

  defp structure,
    do: %Structure{
      sections: [
        Section.new(5, "Networking", [
          Chapter.new(@dns, "Domain Name System (DNS)", slides: @dns_deck)
        ]),
        Section.new(2, "Databases", [Chapter.new(@todolist, "PHP Todolist", graded?: true)])
      ],
      cheatsheets: [Cheatsheet.new("git", "Git Cheatsheet", "Git")]
    }

  defp entry({:document, @todolist}), do: Chapter.new(@todolist, "PHP Todolist", graded?: true)
  defp entry({:cheatsheet, slug}), do: Cheatsheet.new(slug, "Git Cheatsheet", "Git")
  defp entry(:home), do: nil

  defp entry({:document, _ref}),
    do: Chapter.new(@dns, "Domain Name System (DNS)", slides: @dns_deck)

  defp section({:cheatsheet, _slug}), do: nil
  defp section(:home), do: nil
  defp section({:document, @todolist}), do: Section.new(2, "Databases", [])
  defp section({:document, _ref}), do: Section.new(5, "Networking", [])

  defp source_path(:home), do: "index.md"
  defp source_path({:cheatsheet, slug}), do: "_cheatsheets/#{slug}/cheatsheet.md"
  defp source_path({:document, @todolist}), do: "_course/205-php-todolist/exercise.md"
  defp source_path({:document, @dns_deck}), do: "_course/507-dns/slides.md"
  defp source_path({:document, _ref}), do: "_course/507-dns/subject.md"
end
