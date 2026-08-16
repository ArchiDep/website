defmodule ArchiDep.CourseSite.Layout.LayoutContextTest do
  use ExUnit.Case, async: true

  import ArchiDep.Support.CourseSiteFactory, only: [build: 2]

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Layout.LayoutContext
  alias ArchiDep.CourseSite.Progress
  alias ArchiDep.CourseSite.Renderer.Page
  alias ArchiDep.CourseSite.Renderer.PageMetadata
  alias ArchiDep.CourseSite.Session
  alias ArchiDep.CourseSite.SiteInfo
  alias ArchiDep.CourseSite.Structure
  alias ArchiDep.CourseSite.Structure.Chapter
  alias ArchiDep.CourseSite.Structure.Section

  @page {:document, DocumentRef.new(507, "dns", :subject)}
  @content %Page{html: "<p>Learn.</p>", excerpt_html: nil, toc: []}
  @metadata %PageMetadata{
    title: "DNS · ArchiDep",
    page_title: "DNS",
    description: "Learn.",
    canonical_url: nil,
    robots: nil
  }

  describe "new/1" do
    test "gathers what a layout is given" do
      urls = build(:url_context, version: nil)

      site =
        SiteInfo.new(
          version: "0.1.0",
          git_branch: "main",
          git_revision: "abc",
          years: "2025-2026",
          years_short: "25-26"
        )

      chapter = Chapter.new(DocumentRef.new(507, "dns", :subject), "DNS")
      section = Section.new(5, "Deployment", [chapter])
      structure = %Structure{sections: [section], cheatsheets: []}
      progress = Progress.new([Session.new(~D[2026-02-02], "DNS", [500], [507], [])])

      assert LayoutContext.new(
               page: @page,
               source_path: "chapters/507-dns/subject.md",
               content: @content,
               metadata: @metadata,
               entry: chapter,
               section: section,
               front_matter: %{"title" => "DNS"},
               structure: structure,
               progress: progress,
               statuses: %{500 => :done, 507 => :due},
               urls: urls,
               site: site
             ) == %LayoutContext{
               page: @page,
               source_path: "chapters/507-dns/subject.md",
               content: @content,
               metadata: @metadata,
               entry: chapter,
               section: section,
               front_matter: %{"title" => "DNS"},
               structure: structure,
               progress: progress,
               statuses: %{500 => :done, 507 => :due},
               urls: urls,
               site: site
             }
    end

    test "leaves the entry and the section out for a page that is neither" do
      urls = build(:url_context, version: nil)

      site =
        SiteInfo.new(
          version: "0.1.0",
          git_branch: nil,
          git_revision: nil,
          years: "2025-2026",
          years_short: "25-26"
        )

      assert LayoutContext.new(options(urls: urls, site: site)) == %LayoutContext{
               page: @page,
               source_path: "chapters/507-dns/subject.md",
               content: @content,
               metadata: @metadata,
               entry: nil,
               section: nil,
               front_matter: %{"title" => "DNS"},
               structure: %Structure{sections: [], cheatsheets: []},
               progress: Progress.new([]),
               statuses: %{},
               urls: urls,
               site: site
             }
    end

    test "gathers what the home page needs, which is a chapter of nothing" do
      urls = build(:url_context, version: nil)

      site =
        SiteInfo.new(
          version: "0.1.0",
          git_branch: nil,
          git_revision: nil,
          years: "2025-2026",
          years_short: "25-26"
        )

      assert LayoutContext.new(options(page: :home, urls: urls, site: site)) == %LayoutContext{
               page: :home,
               source_path: "chapters/507-dns/subject.md",
               content: @content,
               metadata: @metadata,
               entry: nil,
               section: nil,
               front_matter: %{"title" => "DNS"},
               structure: %Structure{sections: [], cheatsheets: []},
               progress: Progress.new([]),
               statuses: %{},
               urls: urls,
               site: site
             }
    end

    test "refuses a page that is not a page reference" do
      assert_raise ArgumentError,
                   ~s{Page must be a page reference, got: "/course/507-dns/"},
                   fn -> LayoutContext.new(options(page: "/course/507-dns/")) end
    end

    test "refuses content that is neither a page nor a deck" do
      assert_raise ArgumentError,
                   ~s{Content must be a page or a deck, got: "<p>Learn.</p>"},
                   fn -> LayoutContext.new(options(content: "<p>Learn.</p>")) end
    end

    test "refuses the sessions where the record they unite into belongs" do
      assert_raise ArgumentError,
                   "Progress must be a ArchiDep.CourseSite.Progress, got: []",
                   fn -> LayoutContext.new(options(progress: [])) end
    end

    test "refuses statuses that are not chapter numbers" do
      assert_raise ArgumentError,
                   "Statuses must map chapter numbers to statuses, got: %{\"507\" => :due}",
                   fn -> LayoutContext.new(options(statuses: %{"507" => :due})) end
    end

    test "refuses an entry that is neither a chapter nor a cheatsheet" do
      assert_raise ArgumentError,
                   ~s{Entry must be a chapter or a cheatsheet, got: "DNS"},
                   fn -> LayoutContext.new(options(entry: "DNS")) end
    end

    test "refuses a source path that is not a non-empty string" do
      assert_raise ArgumentError,
                   "Source path must be a non-empty string, got: \"\"",
                   fn -> LayoutContext.new(options(source_path: "")) end
    end

    test "refuses metadata that is not what a page says about itself" do
      assert_raise ArgumentError,
                   "Metadata must be a ArchiDep.CourseSite.Renderer.PageMetadata, got: \"DNS\"",
                   fn -> LayoutContext.new(options(metadata: "DNS")) end
    end

    test "refuses front matter that is not a map" do
      assert_raise ArgumentError,
                   "Front matter must be a map, got: [title: \"DNS\"]",
                   fn -> LayoutContext.new(options(front_matter: [title: "DNS"])) end
    end

    test "refuses front matter that is not keyed by strings" do
      assert_raise ArgumentError,
                   "Front matter must be keyed by strings, got: %{title: \"DNS\"}",
                   fn -> LayoutContext.new(options(front_matter: %{title: "DNS"})) end
    end

    test "refuses a structure that is not the course" do
      assert_raise ArgumentError,
                   "Structure must be a ArchiDep.CourseSite.Structure, got: []",
                   fn -> LayoutContext.new(options(structure: [])) end
    end

    test "refuses statuses that are not a map" do
      assert_raise ArgumentError,
                   "Statuses must be a map, got: [{507, :due}]",
                   fn -> LayoutContext.new(options(statuses: [{507, :due}])) end
    end

    test "refuses a URL context that is not one" do
      assert_raise ArgumentError,
                   "URL context must be a ArchiDep.CourseSite.Urls.UrlContext, got: :live",
                   fn -> LayoutContext.new(options(urls: :live)) end
    end

    test "refuses site info that is not a ArchiDep.CourseSite.SiteInfo" do
      assert_raise ArgumentError,
                   "Site info must be a ArchiDep.CourseSite.SiteInfo, got: \"0.1.0\"",
                   fn -> LayoutContext.new(options(site: "0.1.0")) end
    end

    test "refuses a section that is not one of the course's" do
      assert_raise ArgumentError,
                   "Section must be a ArchiDep.CourseSite.Structure.Section, got: \"Deployment\"",
                   fn -> LayoutContext.new(options(section: "Deployment")) end
    end
  end

  defp options(overrides) do
    Keyword.merge(
      [
        page: @page,
        source_path: "chapters/507-dns/subject.md",
        content: @content,
        metadata: @metadata,
        front_matter: %{"title" => "DNS"},
        structure: %Structure{sections: [], cheatsheets: []},
        progress: Progress.new([]),
        statuses: %{},
        urls: build(:url_context, version: nil),
        site:
          SiteInfo.new(
            version: "0.1.0",
            git_branch: nil,
            git_revision: nil,
            years: "2025-2026",
            years_short: "25-26"
          )
      ],
      overrides
    )
  end
end
