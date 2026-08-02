defmodule ArchiDep.CourseSite.Layout.Chrome.DocumentTest do
  use ExUnit.Case, async: true

  import ArchiDep.Support.CourseSiteChrome, only: [render: 2]

  alias ArchiDep.CourseSite.Layout.Chrome.Article
  alias ArchiDep.CourseSite.Layout.Chrome.Assigns
  alias ArchiDep.CourseSite.Layout.Chrome.Banner
  alias ArchiDep.CourseSite.Layout.Chrome.Document
  alias ArchiDep.CourseSite.Layout.Chrome.Header
  alias ArchiDep.CourseSite.Layout.Chrome.Policy
  alias ArchiDep.CourseSite.Layout.Chrome.Sidebar
  alias ArchiDep.CourseSite.Renderer.Page
  alias ArchiDep.CourseSite.SiteInfo

  @links %{
    home: "/",
    theme_css: "/assets/theme/theme-abc.css",
    course_js: "/assets/course/course-abc.js",
    favicon: "/favicon.ico",
    favicon_16: "/favicons/archidep-rocket-16.png",
    favicon_32: "/favicons/archidep-rocket-32.png",
    favicon_48: "/favicons/archidep-rocket-48.png",
    favicon_96: "/favicons/archidep-rocket-96.png",
    favicon_180: "/favicons/archidep-rocket-180.png",
    favicon_192: "/favicons/archidep-rocket-192.png",
    heig_logo: "/favicons/heig.png",
    coffee_logo: "/favicons/archidep-coffee.png",
    repository: "https://github.com/ArchiDep/website"
  }

  @banner_url "https://archidep.example.com/latest?to=/2025/cheatsheets/git/"

  describe "document/1" do
    test "wraps a page in the whole of what a browser receives" do
      assert document() == expected([])
    end

    test "tells the script where the site is mounted and that this is the live one" do
      assert document(base_path: "/2025") ==
               expected(base_path: "/2025", standalone: "false")
    end

    test "tells the script that a build which is not the live site stands in for it" do
      assert document(standalone?: true) == expected(standalone: "true")
    end

    test "tells a reader of an archived edition that it is over, under the header" do
      assert document(banner: :archive, standalone?: true) ==
               expected(standalone: "true", banner: banner_markup(:archive))
    end

    test "tells a reader of the backup copy where the site it stands in for is" do
      assert document(banner: :backup, standalone?: true) ==
               expected(standalone: "true", banner: banner_markup(:backup))
    end

    test "marks the home page's own entry in the navigation when that is the page" do
      assert document(kind: :home) ==
               expected(
                 article: article_markup(kind: :home),
                 sidebar: sidebar_markup(home?: true)
               )
    end
  end

  defp document(overrides \\ []), do: render(&Document.document/1, %{page: page(overrides)})

  defp page(overrides) do
    %Assigns{
      ref: {:cheatsheet, "git"},
      kind: Keyword.get(overrides, :kind, :cheatsheet),
      title: "Git Cheatsheet",
      graded?: false,
      content: %Page{html: "<p>Commit.</p>", excerpt_html: nil, toc: []},
      toc: [],
      metadata_html: "<title>Git Cheatsheet · ArchiDep</title>",
      policy: live_policy(),
      banner: Keyword.get(overrides, :banner),
      site: site(),
      commit: "main@abc123",
      sections: [],
      cheatsheets: [],
      cards: [],
      base_path: Keyword.get(overrides, :base_path, ""),
      standalone?: Keyword.get(overrides, :standalone?, false),
      legend_emoji: %{},
      page_class: "course-cheatsheet",
      cloud_server: nil,
      pdf_tooltip: "Cheatsheet PDF",
      links: links(Keyword.get(overrides, :banner))
    }
  end

  defp links(nil), do: @links
  defp links(_kind), do: Map.put(@links, :banner, @banner_url)

  # What each part draws is pinned by that part's own test; what this one is
  # about is the document those parts are placed in — the head a browser reads
  # before anything, the drawer the navigation slides out of, and the two things
  # the head says to a script rather than to a browser.
  defp expected(parts) do
    String.trim_trailing("""
    <!DOCTYPE html>
    <html lang="en">
      <head data-base-path="#{Keyword.get(parts, :base_path, "")}" data-archidep-standalone="#{Keyword.get(parts, :standalone, "false")}">
        <meta charset="utf-8">
        <meta http-equiv="X-UA-Compatible" content="IE=edge">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Git Cheatsheet · ArchiDep</title>
        <link rel="preconnect" href="https://fonts.googleapis.com">
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
        <link rel="stylesheet" href="/assets/theme/theme-abc.css">
        <link rel="icon" type="image/png" sizes="16x16" href="/favicons/archidep-rocket-16.png">
        <link rel="icon" type="image/png" sizes="32x32" href="/favicons/archidep-rocket-32.png">
        <link rel="icon" type="image/png" sizes="48x48" href="/favicons/archidep-rocket-48.png">
        <link rel="icon" type="image/png" sizes="96x96" href="/favicons/archidep-rocket-96.png">
        <link rel="icon" type="image/png" sizes="192x192" href="/favicons/archidep-rocket-192.png">
        <link rel="apple-touch-icon" sizes="180x180" href="/favicons/archidep-rocket-180.png">
        <link rel="shortcut icon" href="/favicon.ico">
        <script src="/assets/course/course-abc.js" defer>
        </script>
      </head>

      <body class="group/body">
        <div id="top" class="top-0 h-0"></div>

        <script type="text/javascript">
          if (localStorage.getItem('archidep.alwaysTellMeMore')) {
            const alwaysTellMeMore = document.createElement('div');
            alwaysTellMeMore.id = 'always-tell-me-more';
            alwaysTellMeMore.classList.add('hidden');
            document.body.prepend(alwaysTellMeMore);
          }
        </script>

        #{Keyword.get(parts, :header, header_markup())}

        #{Keyword.get(parts, :banner, "")}

        <div class="drawer lg:drawer-open">
          <input id="sidebar" type="checkbox" class="drawer-toggle">
          <div class="drawer-content">
            <div class="md:p-4">
              #{Keyword.get(parts, :article, article_markup([]))}
            </div>
          </div>
          <div class="drawer-side z-20">
            <label for="sidebar" aria-label="close sidebar" class="drawer-overlay"></label>
            #{Keyword.get(parts, :sidebar, sidebar_markup([]))}
          </div>
        </div>
      </body>
    </html>
    """)
  end

  defp header_markup,
    do: render(&Header.header/1, %{links: @links, policy: live_policy(), site: site()})

  defp banner_markup(kind),
    do: render(&Banner.banner/1, %{kind: kind, url: @banner_url, years: "2025-2026"})

  defp article_markup(parts), do: render(&Article.article/1, %{page: page(parts)})

  defp sidebar_markup(parts),
    do:
      render(&Sidebar.sidebar/1, %{
        sections: [],
        cheatsheets: [],
        cards: [],
        links: @links,
        policy: live_policy(),
        home?: Keyword.get(parts, :home?, false),
        version: "1.2.3",
        commit: "main@abc123"
      })

  defp live_policy,
    do: %Policy{app_navigation?: true, account?: true, badges?: true, progress_cards?: true}

  defp site,
    do:
      SiteInfo.new(
        version: "1.2.3",
        git_branch: "main",
        git_revision: "abc123",
        years: "2025-2026",
        years_short: "25-26"
      )
end
