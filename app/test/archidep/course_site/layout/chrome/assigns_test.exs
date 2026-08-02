defmodule ArchiDep.CourseSite.Layout.Chrome.AssignsTest do
  use ExUnit.Case, async: true

  import ArchiDep.Support.CourseSiteFactory, only: [build: 2]

  alias ArchiDep.CourseSite.DocumentRef
  alias ArchiDep.CourseSite.Layout.Chrome.Assigns
  alias ArchiDep.CourseSite.Layout.Chrome.HomeCard
  alias ArchiDep.CourseSite.Layout.Chrome.MenuEntry
  alias ArchiDep.CourseSite.Layout.Chrome.MenuSection
  alias ArchiDep.CourseSite.Layout.Chrome.Policy
  alias ArchiDep.CourseSite.Layout.LayoutContext
  alias ArchiDep.CourseSite.Progress
  alias ArchiDep.CourseSite.Renderer.Page
  alias ArchiDep.CourseSite.Renderer.PageMetadata
  alias ArchiDep.CourseSite.Renderer.Slides
  alias ArchiDep.CourseSite.Renderer.Toc.Entry
  alias ArchiDep.CourseSite.Session
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

  @page_assets ["/assets/theme/theme.css", "/assets/course/course.js"]
  @deck_assets [
    "/assets/course/slides.css",
    "/assets/theme/slides.css",
    "/assets/course/slides.js",
    "/assets/course/slides-mermaid.js"
  ]

  # The two sets of pictures the chrome resolves, keyed as it keys them: the
  # navigation's, sized and labelled, and the legend's, drawn as prose. Trophy
  # is in both, under a key of its own in each.
  @menu_emoji %{
    emoji_subject: {"book", "Subject"},
    emoji_cheatsheet: {"memo", "Cheatsheet"},
    emoji_graded_exercise: {"trophy", "Graded exercise"},
    emoji_exercise: {"hammer_and_wrench", "Exercise"},
    emoji_slides: {"clapper", "Slides"}
  }

  @legend_emoji %{
    legend_trophy: "trophy",
    legend_scroll: "scroll",
    legend_exclamation: "exclamation",
    legend_question: "question",
    legend_space_invader: "space_invader",
    legend_checkered_flag: "checkered_flag",
    legend_classical_building: "classical_building",
    legend_boom: "boom"
  }

  describe "build/1" do
    test "works out everything a chapter is drawn from" do
      assert Assigns.build(context()) == {:ok, expected()}
    end

    test "works out everything an exercise is drawn from" do
      assert Assigns.build(context(page: {:document, @todolist})) ==
               {:ok,
                expected(
                  ref: {:document, @todolist},
                  kind: :exercise,
                  graded?: true,
                  page_class: "course-exercise",
                  pdf_tooltip: "Exercise PDF",
                  toc: [
                    heading("graded-exercise", "#{emoji("trophy")} Graded exercise"),
                    heading("legend", "#{emoji("scroll")} Legend"),
                    page_heading()
                  ],
                  sections: sections(current: {:document, @todolist}),
                  links:
                    links(
                      deck: false,
                      source:
                        source_url("course/collections/_course/205-php-todolist/exercise.md")
                    )
                )}
    end

    test "works out everything a cheatsheet is drawn from" do
      assert Assigns.build(context(page: {:cheatsheet, "git"})) ==
               {:ok,
                expected(
                  ref: {:cheatsheet, "git"},
                  kind: :cheatsheet,
                  page_class: "course-cheatsheet",
                  pdf_tooltip: "Cheatsheet PDF",
                  toc: [page_heading()],
                  sections: sections(current: nil),
                  cheatsheets: [cheatsheet_entry(current?: true)],
                  links:
                    links(
                      deck: false,
                      source: source_url("course/collections/_cheatsheets/git/cheatsheet.md")
                    )
                )}
    end

    test "works out everything the page introducing the course is drawn from" do
      assert Assigns.build(context(page: :home)) ==
               {:ok,
                expected(
                  ref: :home,
                  kind: :home,
                  page_class: "course-home",
                  pdf_tooltip: "Home PDF",
                  toc: [page_heading()],
                  sections: sections(current: nil),
                  cards: [
                    %HomeCard{kind: :previously, entries: [dns_entry("", nil)]},
                    %HomeCard{kind: :due_next, entries: [todolist_entry("", nil)]}
                  ],
                  links: links(deck: false, source: source_url("course/index.md"))
                )}
    end

    test "shows the home page of a course nobody has taught yet no cards at all" do
      assert Assigns.build(context(page: :home, progress: Progress.new([]))) ==
               {:ok,
                expected(
                  ref: :home,
                  kind: :home,
                  page_class: "course-home",
                  pdf_tooltip: "Home PDF",
                  toc: [page_heading()],
                  sections: sections(current: nil),
                  links: links(deck: false, source: source_url("course/index.md"))
                )}
    end

    test "works out everything a deck is drawn from, which is not what a page loads" do
      deck = %Slides{markdown: "# DNS\n"}

      assert Assigns.build(context(page: {:document, @dns_deck}, content: deck)) ==
               {:ok,
                expected(
                  ref: {:document, @dns_deck},
                  kind: :deck,
                  content: deck,
                  page_class: "course-deck",
                  pdf_tooltip: "Slides PDF",
                  toc: [],
                  sections: sections(current: nil),
                  links:
                    links(
                      assets: @deck_assets,
                      source: source_url("course/collections/_course/507-dns/slides.md")
                    )
                )}
    end

    test "leaves out everything a build that is not the live site does not carry" do
      urls =
        build(:url_context, base_path: "", version: "2025", mode: :archive, assets: manifest())

      assert Assigns.build(context(urls: urls)) ==
               {:ok,
                expected(
                  base_path: "/2025",
                  standalone?: true,
                  policy: archived_policy(),
                  sections: sections(prefix: "/2025"),
                  cheatsheets: [cheatsheet_entry(prefix: "/2025")],
                  legend_emoji: legend_emoji("/2025"),
                  links: archived_links()
                )}
    end

    test "says nothing about where an archived edition got to, whatever its progress says" do
      urls =
        build(:url_context, base_path: "", version: "2025", mode: :archive, assets: manifest())

      assert Assigns.build(context(page: :home, urls: urls)) ==
               {:ok,
                expected(
                  ref: :home,
                  kind: :home,
                  page_class: "course-home",
                  pdf_tooltip: "Home PDF",
                  toc: [page_heading()],
                  base_path: "/2025",
                  standalone?: true,
                  policy: archived_policy(),
                  sections: sections(prefix: "/2025", current: nil),
                  cheatsheets: [cheatsheet_entry(prefix: "/2025")],
                  legend_emoji: legend_emoji("/2025"),
                  links: archived_home_links()
                )}
    end

    test "leaves the dashboard out of the backup copy as well, which still says where the course has got to" do
      urls =
        build(:url_context, base_path: "", version: "2025", mode: :backup, assets: manifest())

      assert Assigns.build(context(page: :home, urls: urls)) ==
               {:ok,
                expected(
                  ref: :home,
                  kind: :home,
                  page_class: "course-home",
                  pdf_tooltip: "Home PDF",
                  toc: [page_heading()],
                  base_path: "/2025",
                  standalone?: true,
                  policy: backup_policy(),
                  sections: sections(prefix: "/2025", current: nil),
                  cheatsheets: [cheatsheet_entry(prefix: "/2025")],
                  cards: [
                    %HomeCard{kind: :previously, entries: [dns_entry("/2025", nil)]},
                    %HomeCard{kind: :due_next, entries: [todolist_entry("/2025", nil)]}
                  ],
                  legend_emoji: legend_emoji("/2025"),
                  links: backup_home_links()
                )}
    end

    test "offers no source at all for a checkout that cannot name its revision" do
      assert Assigns.build(context(git_revision: nil)) ==
               {:ok,
                expected(
                  site: site(git_revision: nil),
                  commit: nil,
                  links: Map.delete(links(), :source)
                )}
    end
  end

  describe "build/1 failures" do
    test "reports every asset the chrome could not resolve, not the first" do
      assert Assigns.build(context(assets: [])) ==
               {:error, missing(@page_assets ++ emoji_assets())}
    end

    test "asks a deck for the files a deck loads rather than the files a page loads" do
      assert Assigns.build(context(content: %Slides{markdown: "# DNS\n"}, assets: [])) ==
               {:error, missing(@deck_assets ++ emoji_assets())}
    end
  end

  describe "kind/1" do
    test "lays a chapter's subject out as a subject" do
      assert Assigns.kind(context()) == :subject
    end

    test "lays a chapter's exercise out as an exercise" do
      assert Assigns.kind(context(page: {:document, @todolist})) == :exercise
    end

    test "lays a cheatsheet out as a cheatsheet" do
      assert Assigns.kind(context(page: {:cheatsheet, "git"})) == :cheatsheet
    end

    test "lays the page introducing the course out as the home page" do
      assert Assigns.kind(context(page: :home)) == :home
    end

    test "lays whatever was rendered as slides out as a deck" do
      assert Assigns.kind(context(content: %Slides{markdown: "# DNS\n"})) == :deck
    end
  end

  describe "heading_id/1" do
    test "names the heading a presented chapter opens with" do
      assert Assigns.heading_id(:presentation) == "presentation"
    end

    test "names the heading a graded exercise opens with" do
      assert Assigns.heading_id(:graded) == "graded-exercise"
    end

    test "names the heading every exercise's key sits under" do
      assert Assigns.heading_id(:legend) == "legend"
    end
  end

  # The whole of what a chapter is drawn from, which each case is handed and
  # changes only what it is about.
  defp expected(overrides \\ []) do
    %Assigns{
      ref: Keyword.get(overrides, :ref, {:document, @dns}),
      kind: Keyword.get(overrides, :kind, :subject),
      title: "Domain Name System (DNS)",
      graded?: Keyword.get(overrides, :graded?, false),
      content: Keyword.get(overrides, :content, page_content()),
      toc:
        Keyword.get(overrides, :toc, [heading("presentation", "Presentation"), page_heading()]),
      metadata_html: PageMetadata.to_html(metadata()),
      policy: Keyword.get(overrides, :policy, live_policy()),
      site: Keyword.get(overrides, :site, site()),
      commit: Keyword.get(overrides, :commit, "main@abc123"),
      sections: Keyword.get(overrides, :sections, sections()),
      cheatsheets: Keyword.get(overrides, :cheatsheets, [cheatsheet_entry()]),
      cards: Keyword.get(overrides, :cards, []),
      base_path: Keyword.get(overrides, :base_path, ""),
      standalone?: Keyword.get(overrides, :standalone?, false),
      legend_emoji: Keyword.get(overrides, :legend_emoji, legend_emoji("")),
      page_class: Keyword.get(overrides, :page_class, "course-subject"),
      cloud_server: Keyword.get(overrides, :cloud_server, nil),
      pdf_tooltip: Keyword.get(overrides, :pdf_tooltip, "Subject PDF"),
      links: Keyword.get(overrides, :links, links())
    }
  end

  defp live_policy,
    do: %Policy{app_navigation?: true, account?: true, badges?: true, progress_cards?: true}

  defp archived_policy,
    do: %Policy{app_navigation?: false, account?: false, badges?: false, progress_cards?: false}

  defp backup_policy,
    do: %Policy{app_navigation?: false, account?: false, badges?: false, progress_cards?: true}

  # What an archived edition writes instead: everything under the edition's own
  # prefix but the files anchored at the mount point, which stay where a browser
  # and an operating system look for them.
  defp archived_links do
    Map.merge(links(), %{
      home: "/2025/",
      theme_css: "/2025/assets/theme/theme.css",
      course_js: "/2025/assets/course/course.js",
      deck: "/2025/course/507-dns/slides/",
      emoji_subject: "/2025/assets/emoji/1f4d6.svg",
      emoji_cheatsheet: "/2025/assets/emoji/1f4dd.svg",
      emoji_graded_exercise: "/2025/assets/emoji/1f3c6.svg",
      emoji_exercise: "/2025/assets/emoji/1f6e0.svg",
      emoji_slides: "/2025/assets/emoji/1f3ac.svg",
      legend_trophy: "/2025/assets/emoji/1f3c6.svg",
      legend_scroll: "/2025/assets/emoji/1f4dc.svg",
      legend_exclamation: "/2025/assets/emoji/2757.svg",
      legend_question: "/2025/assets/emoji/2753.svg",
      legend_space_invader: "/2025/assets/emoji/1f47e.svg",
      legend_checkered_flag: "/2025/assets/emoji/1f3c1.svg",
      legend_classical_building: "/2025/assets/emoji/1f3db.svg",
      legend_boom: "/2025/assets/emoji/1f4a5.svg"
    })
  end

  # The same edition's home page, which has no deck to link to and is written
  # somewhere else.
  defp archived_home_links,
    do:
      archived_links()
      |> Map.delete(:deck)
      |> Map.put(:source, source_url("course/index.md"))

  # The home page of the copy of the edition being taught, which writes its
  # content where that edition writes it but keeps its own home page at the
  # mount point, as the site it copies does.
  defp backup_home_links, do: Map.put(archived_home_links(), :home, "/")

  # Every URL the chrome of a page writes. No PDF is ever among them: nothing
  # populates the manifest, so no page offers a download.
  defp links(overrides \\ []) do
    assets = Keyword.get(overrides, :assets, @page_assets)

    %{
      home: "/",
      favicon: "/favicon.ico",
      favicon_16: "/favicons/archidep-rocket-16.png",
      favicon_32: "/favicons/archidep-rocket-32.png",
      favicon_48: "/favicons/archidep-rocket-48.png",
      favicon_96: "/favicons/archidep-rocket-96.png",
      favicon_180: "/favicons/archidep-rocket-180.png",
      favicon_192: "/favicons/archidep-rocket-192.png",
      heig_logo: "/favicons/heig.png",
      logo: "/favicons/archidep-512-flat.png",
      coffee_logo: "/favicons/archidep-coffee.png",
      repository: "https://github.com/ArchiDep/website",
      branch: "https://github.com/ArchiDep/website/tree/main",
      source:
        Keyword.get(
          overrides,
          :source,
          source_url("course/collections/_course/507-dns/subject.md")
        )
    }
    |> Map.merge(Map.new(assets, &{asset_key(&1), &1}))
    |> Map.merge(Map.new(@menu_emoji, fn {key, {name, _alt}} -> {key, emoji_path(name)} end))
    |> Map.merge(Map.new(@legend_emoji, fn {key, name} -> {key, emoji_path(name)} end))
    |> deck_link(Keyword.get(overrides, :deck, true))
  end

  # Only a chapter that has one links to a deck.
  defp deck_link(links, false), do: links
  defp deck_link(links, true), do: Map.put(links, :deck, "/course/507-dns/slides/")

  defp asset_key("/assets/theme/theme.css"), do: :theme_css
  defp asset_key("/assets/course/course.js"), do: :course_js
  defp asset_key("/assets/course/slides.css"), do: :slides_css
  defp asset_key("/assets/theme/slides.css"), do: :theme_slides_css
  defp asset_key("/assets/course/slides.js"), do: :slides_js
  defp asset_key("/assets/course/slides-mermaid.js"), do: :slides_mermaid_js

  defp source_url(path), do: "https://github.com/ArchiDep/website/blob/abc123/#{path}"

  defp sections(overrides \\ []) do
    prefix = Keyword.get(overrides, :prefix, "")
    current = Keyword.get(overrides, :current, {:document, @dns})

    [
      %MenuSection{
        title: "Networking",
        slug: "networking",
        status: :due,
        open?: true,
        entries: [dns_entry(prefix, current)]
      },
      %MenuSection{
        title: "Databases",
        slug: "databases",
        status: :future,
        open?: false,
        entries: [todolist_entry(prefix, current)]
      }
    ]
  end

  # The lines the course is listed as, which the navigation and the home page's
  # cards are both drawn from.
  defp dns_entry(prefix, current),
    do: %MenuEntry{
      url: "#{prefix}/course/507-dns/",
      title: "Domain Name System (DNS)",
      emoji_html: menu_emoji(prefix, "book", "Subject"),
      deck_emoji_html: menu_emoji(prefix, "clapper", "Slides"),
      status: :due,
      current?: current == {:document, @dns},
      deck?: false
    }

  defp todolist_entry(prefix, current),
    do: %MenuEntry{
      url: "#{prefix}/course/205-php-todolist/",
      title: "PHP Todolist",
      emoji_html: menu_emoji(prefix, "trophy", "Graded exercise"),
      deck_emoji_html: nil,
      status: :future,
      current?: current == {:document, @todolist},
      deck?: false
    }

  defp cheatsheet_entry(overrides \\ []) do
    prefix = Keyword.get(overrides, :prefix, "")

    %MenuEntry{
      url: "#{prefix}/cheatsheets/git/",
      title: "Git",
      emoji_html: menu_emoji(prefix, "memo", "Cheatsheet"),
      deck_emoji_html: nil,
      status: nil,
      current?: Keyword.get(overrides, :current?, false),
      deck?: false
    }
  end

  defp legend_emoji(prefix),
    do:
      Map.new(@legend_emoji, fn {_key, name} ->
        {name, Emoji.img(Emoji.fetch!(name), prefix <> emoji_path(name))}
      end)

  defp menu_emoji(prefix, name, alt),
    do: Emoji.img(Emoji.fetch!(name), prefix <> emoji_path(name), alt: alt, class: "size-4")

  defp emoji(name), do: Emoji.img(Emoji.fetch!(name), emoji_path(name))

  defp emoji_path(name), do: Emoji.asset_path(Emoji.fetch!(name))

  defp heading(id, label), do: %Entry{id: id, level: 2, label_html: label, entries: []}
  defp page_heading, do: heading("what", "What")

  defp missing(paths),
    do: paths |> Enum.uniq() |> Enum.sort() |> Enum.map(&{:unknown_asset, &1})

  defp context(overrides \\ []) do
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
      progress: Keyword.get(overrides, :progress, progress()),
      statuses: %{500 => :due, 507 => :due},
      urls:
        Keyword.get_lazy(overrides, :urls, fn ->
          build(:url_context,
            mode: :live,
            base_path: "",
            version: nil,
            assets: manifest(overrides)
          )
        end),
      site: site(Keyword.take(overrides, [:git_revision]))
    )
  end

  defp manifest(overrides \\ []) do
    paths = Keyword.get(overrides, :assets, @page_assets ++ @deck_assets ++ emoji_assets())

    AssetManifest.new(Map.new(paths, &{&1, &1}))
  end

  defp emoji_assets do
    menu = Enum.map(@menu_emoji, fn {_key, {name, _alt}} -> emoji_path(name) end)
    legend = Enum.map(@legend_emoji, fn {_key, name} -> emoji_path(name) end)

    menu ++ legend
  end

  defp site(overrides \\ []) do
    [
      version: "1.2.3",
      git_branch: "main",
      git_revision: "abc123",
      years: "2025-2026",
      years_short: "25-26"
    ]
    |> Keyword.merge(overrides)
    |> SiteInfo.new()
  end

  defp page_content,
    do: %Page{
      html: "<h2 id=\"what\">What</h2>",
      excerpt_html: "<p>A name.</p>",
      toc: [page_heading()]
    }

  defp metadata,
    do: %PageMetadata{
      title: "Domain Name System (DNS) · ArchiDep",
      page_title: "Domain Name System (DNS)",
      description: "A name.",
      canonical_url: nil
    }

  # One session, which finished the chapter the tests are about and set work on
  # the other: enough for two of the home page's three cards and none of the
  # third.
  defp progress, do: Progress.new([Session.new(~D[2026-02-02], "DNS", [500, 507], [205], [])])

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
